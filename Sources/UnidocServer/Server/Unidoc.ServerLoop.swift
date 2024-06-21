import GitHubAPI
import HTTP
import HTTPServer
import MongoDB
import PieCharts
import UnidocRender

extension Unidoc
{
    public final
    class ServerLoop:Sendable
    {
        public
        let context:ServerPluginContext
        public
        let plugins:[String: any ServerPlugin]
        @usableFromInline
        let options:ServerOptions
        public
        let db:Database

        private
        let updateQueue:AsyncStream<Update>.Continuation,
            updates:AsyncStream<Update>

        private
        let graphState:GraphStateLoop

        let policy:(any HTTP.ServerPolicy)?
        @usableFromInline
        let logger:(any ServerLogger)?

        public
        init(
            plugins:[any ServerPlugin],
            context:ServerPluginContext,
            options:ServerOptions,
            graphState:GraphStateLoop,
            logger:(any ServerLogger)? = nil,
            db:Database)
        {
            var policy:(any HTTP.ServerPolicy)? = nil

            for case let plugin as any HTTP.ServerPolicy in plugins
            {
                policy = plugin
                break
            }

            self.plugins = plugins.reduce(into: [:]) { $0[$1.id] = $1 }
            self.context = context
            self.options = options
            self.graphState = graphState
            self.policy = policy
            self.logger = logger
            self.db = db

            (self.updates, self.updateQueue) = AsyncStream<Update>.makeStream(
                bufferingPolicy: .bufferingOldest(16))
        }
    }
}
extension Unidoc.ServerLoop
{
    @inlinable public
    var security:Unidoc.ServerSecurity
    {
        switch self.options.mode
        {
        case .development(_, let options):  options.security
        case .production:                   .enforced
        }
    }

    @inlinable public
    var github:GitHub.Integration? { self.options.github }
    @inlinable public
    var bucket:Unidoc.Buckets { self.options.bucket }

    @inlinable public
    var format:Unidoc.RenderFormat
    {
        self.format(locale: nil)
    }

    @inlinable
    func format(locale:HTTP.Locale?) -> Unidoc.RenderFormat
    {
        .init(assets: self.options.cloudfront ? .cloudfront : .local,
            security: self.security,
            locale: locale,
            server: self.options.mode.server)
    }
}
extension Unidoc.ServerLoop
{
    //  TODO: this really should be manually-triggered and should not run every time.
    func _setup() async throws
    {
        let session:Mongo.Session = try await .init(from: self.db.sessions)

        //  Create the machine user, if it doesn’t exist. Don’t store the cookie, since we
        //  want to be able to change it without restarting the server.
        let _:Unidoc.UserSecrets = try await self.db.users.update(user: .machine(0),
            with: session)
    }

    func update() async throws
    {
        for await update:Update in self.updates
        {
            try Task.checkCancellation()

            let promise:Promise = update.promise
            let payload:[UInt8] = update.payload

            await (/* consume */ update).operation.perform(on: self,
                payload: payload,
                request: promise)
        }
    }
}
extension Unidoc.ServerLoop
{
    private
    func clearance(by authorization:Unidoc.Authorization) async throws -> HTTP.ServerResponse?
    {
        guard case .production = self.options.mode
        else
        {
            return nil
        }

        let user:Unidoc.UserSession

        switch authorization
        {
        case .invalid(let error):   return .unauthorized("\(error)\n")
        case .web(nil, _):          return .unauthorized("Unauthorized\n")
        case .web(let session?, _): user = .web(session)
        case .api(let session):     user = .api(session)
        }

        let session:Mongo.Session = try await .init(from: self.db.sessions)

        guard
        let rights:Unidoc.UserRights = try await self.db.users.validate(user: user,
            with: session)
        else
        {
            return .notFound("No such user\n")
        }

        switch rights.level
        {
        case .administratrix:   return nil
        case .machine:          return nil
        case .human:            return .forbidden("")
        case .guest:            return .unauthorized("")
        }
    }
}

extension Unidoc.ServerLoop
{
    public
    func clearance(for request:Unidoc.StreamedRequest) async throws -> HTTP.ServerResponse?
    {
        try await self.clearance(by: request.authorization)
    }

    public
    func response(for request:Unidoc.StreamedRequest,
        with body:__owned [UInt8]) async -> HTTP.ServerResponse
    {
        await self.submit(update: request.endpoint, with: body)
    }

    public
    func response(for request:Unidoc.IntegralRequest) async throws -> HTTP.ServerResponse
    {
        switch request.assignee
        {
        case .actor(let operation):
            return try await self.respond(to: request.incoming, running: operation)

        case .update(let procedural):
            if  let failure:HTTP.ServerResponse = try await self.clearance(
                    by: request.incoming.authorization)
            {
                return failure
            }

            return await self.submit(update: procedural)

        case .syncError(let message):
            return .resource(.init(content: .init(
                    body: .string(message),
                    type: .text(.plain, charset: .utf8))),
                status: 400)

        case .syncResource(let renderable):
            return .ok(renderable.resource(format: self.format))

        case .syncRedirect(let target):
            return .redirect(target)

        case .syncLoad(let request):
            guard case .development(let cache, _) = self.options.mode
            else
            {
                //  In production mode, static assets are served by Cloudfront.
                return .forbidden("")
            }

            return try await cache.serve(request)
        }
    }
}
extension Unidoc.ServerLoop
{
    private
    func submit(update operation:any Unidoc.ProceduralOperation,
        with body:__owned [UInt8] = []) async -> HTTP.ServerResponse
    {
        await withCheckedContinuation
        {
            guard case .enqueued = self.updateQueue.yield(.init(operation: operation,
                payload: body,
                promise: .init($0)))
            else
            {
                $0.resume(returning: .resource("", status: 503))
                return
            }
        }
    }

    /// As this function participates in cooperative cancellation, it can throw, and the only
    /// error it can throw is a ``CancellationError``.
    private
    func respond(to request:Unidoc.IncomingRequest,
        running operation:any Unidoc.InteractiveOperation) async throws -> HTTP.ServerResponse
    {
        do
        {
            try Task.checkCancellation()

            let initiated:ContinuousClock.Instant = .now

            let response:HTTP.ServerResponse = try await operation.load(
                from: .init(wrapping: self),
                with: .init(authorization: request.authorization, request: request.uri),
                as: self.format(locale: request.origin.guess?.locale)) ?? .notFound("not found")

            //  Don’t log these operations, as doing so would make it impossible for admins to
            //  avoid leaving trails.
            switch operation
            {
            case is Unidoc.LoadDashboardOperation:  return response
            case is Unidoc.LoginOperation:          return response
            case is Unidoc.AuthOperation:           return response
            default:                                break
            }

            self.logger?.log(request: request, with: response, time: .now - initiated)
            return response
        }
        catch let error as CancellationError
        {
            throw error
        }
        catch let error
        {
            self.logger?.log(request: request, with: error)

            let page:Unidoc.ServerErrorPage = .init(error: error)
            return .error(page.resource(format: self.format))
        }
    }
}
