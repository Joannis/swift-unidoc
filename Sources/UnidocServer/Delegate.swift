import HTTPServer
import MongoDB
import Multiparts
import NIOCore
import NIOPosix
import NIOHTTP1
import SymbolGraphs
import UnidocDatabase

final
actor Delegate
{
    private nonisolated
    let requests:(in:AsyncStream<AnyRequest>.Continuation, out:AsyncStream<AnyRequest>)

    private nonisolated
    let database:Database
    private nonisolated
    let mongodb:Mongo.SessionPool

    private
    init(database:Database, mongodb:Mongo.SessionPool)
    {
        var continuation:AsyncStream<AnyRequest>.Continuation? = nil
        self.requests.out = .init
        {
            continuation = $0
        }
        self.requests.in = continuation!

        self.database = database
        self.mongodb = mongodb
    }
}
extension Delegate
{
    func respond() async throws
    {
        for await request:AnyRequest in self.requests.out
        {
            try Task.checkCancellation()
            do
            {
                let resource:ServerResource
                switch request
                {
                case .get(let request):
                    resource = try await self.respond(to: request)

                case .post(let request):
                    resource = try await self.respond(to: request)
                }
                request.promise.succeed(resource)
            }
            catch let error
            {
                request.promise.fail(error)
            }
        }
    }

    private
    func respond(to request:GetRequest) async throws -> ServerResource
    {
        if  request.uri == "/admin"
        {
            let configuration:Mongo.ReplicaSetConfiguration = try await self.mongodb.run(
                command: Mongo.ReplicaSetGetConfiguration.init(),
                against: .admin)

            return .init(location: request.uri,
                response: .content(.init(.text("\(configuration)"),
                    type: .text(.plain, charset: .utf8))),
                results: .one(canonical: request.uri))
        }
        else
        {
            return .init(location: request.uri,
                response: .content(.init(.text("""
                    <!DOCTYPE html>
                    <html lang="en">
                    <head>
                    <meta charset="utf-8"/>
                    <title>upload</title>
                    </head>
                    <body>
                    <form action="/upload" method="post" enctype="multipart/form-data">
                    <p><input type="text" name="text1" value="text default"></p>
                    <p><input type="file" name="documentation-binary"></p>
                    <p><button type="submit">Submit</button></p>
                    </form>
                    </body>
                    </html>
                    """),
                    type: .text(.html, charset: .utf8))),
                results: .one(canonical: request.uri))
        }
    }

    private
    func respond(to request:PostRequest) async throws -> ServerResource
    {
        var receipts:[SnapshotReceipt] = []
        for item:MultipartForm.Item in request.form
            where item.header.name == "documentation-binary"
        {
            receipts.append(try await self.ingest(uploaded: try .init(buffer: item.value)))
        }
        return .init(location: request.uri,
                response: .content(.init(.text("success! \(receipts)"),
                    type: .text(.plain, charset: .utf8))),
                results: .one(canonical: request.uri))
    }
}

extension Delegate
{
    private nonisolated
    func ingest(uploaded docs:Documentation) async throws -> SnapshotReceipt
    {
        if  let _:String = docs.metadata.id
        {
            let session:Mongo.Session = try await .init(from: self.mongodb)
            return try await self.database.publish(docs: docs, with: session)
        }
        else
        {
            throw DocumentationIdentificationError.init()
        }
    }
}
extension Delegate:ServerDelegate
{
    nonisolated
    func serve(get request:GetRequest)
    {
        switch self.requests.in.yield(.get(request))
        {
        case .enqueued: return
        case _:         fatalError("unimplemented")
        }
    }
    nonisolated
    func serve(post request:PostRequest)
    {
        switch self.requests.in.yield(.post(request))
        {
        case .enqueued: return
        case _:         fatalError("unimplemented")
        }
    }
}
@main
extension Delegate
{
    public static
    func main() async throws
    {
        let executors:MultiThreadedEventLoopGroup = .init(numberOfThreads: 2)
        let mongodb:Mongo.DriverBootstrap = MongoDB / ["unidoc-mongod"] /?
        {
            $0.executors = .shared(executors)
            $0.appname = "example app"
        }

        defer
        {
            try? executors.syncShutdownGracefully()
        }

        try await mongodb.withSessionPool
        {
            let delegate:Self = .init(database: try await .setup("unidoc", in: $0),
                mongodb: $0)

            try await withThrowingTaskGroup(of: Void.self)
            {
                (tasks:inout ThrowingTaskGroup<Void, any Error>) in

                tasks.addTask
                {
                    try await delegate.serve(from: ("0.0.0.0", 8080),
                        as: .localhost,
                        on: executors)
                }
                tasks.addTask
                {
                    try await delegate.respond()
                }

                for try await _:Void in tasks
                {
                    tasks.cancelAll()
                }
            }
        }
    }
}
