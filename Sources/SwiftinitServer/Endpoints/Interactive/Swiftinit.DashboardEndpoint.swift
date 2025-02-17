import HTTP
import MongoDB
import SwiftinitPages

extension Swiftinit
{
    enum DashboardEndpoint
    {
        case cookie(scramble:Bool)
        case master
        case plugin(String)
        case replicaSet
    }
}
extension Swiftinit.DashboardEndpoint:RestrictedEndpoint
{
    func load(from server:borrowing Swiftinit.Server) async throws -> HTTP.ServerResponse?
    {
        switch self
        {
        case .cookie(scramble: let scramble):
            let session:Mongo.Session = try await .init(from: server.db.sessions)
            let cookie:Unidoc.Cookie

            switch scramble
            {
            case true:
                guard
                let changed:Unidoc.Cookie = try await server.db.users.scramble(
                    user: .init(type: .unidoc, user: 0),
                    with: session)
                else
                {
                    //  If, for some reason, the account has disappeared, we'll just create
                    //  a new one.
                    fallthrough
                }

                cookie = changed

            case false:
                cookie = try await server.db.users.update(
                    user: .machine(0),
                    with: session)
            }

            let page:Swiftinit.CookiePage = .init(cookie: "\(cookie)")
            return .ok(page.resource(format: server.format))

        case .master:
            let page:Swiftinit.AdminPage = .init(
                servers: await server.db.sessions._servers(),
                plugins: server.plugins.values.sorted { $0.id < $1.id },
                tour: server.tour,
                real: server.secure)

            return .ok(page.resource(format: server.format))

        case .plugin(let id):
            guard
            let plugin:any Swiftinit.ServerPlugin = server.plugins[id]
            else
            {
                return .notFound("No such plugin")
            }
            guard
            let page:any Swiftinit.RenderablePage = plugin.page
            else
            {
                return .notFound("This plugin has not been initialized yet")
            }

            return .ok(page.resource(format: server.format))

        case .replicaSet:
            let configuration:Mongo.ReplicaSetConfiguration = try await server.db.sessions.run(
                command: Mongo.ReplicaSetGetConfiguration.init(),
                against: .admin)

            let page:Swiftinit.ReplicaSetPage = .init(configuration: configuration)
            return .ok(page.resource(format: server.format))
        }
    }
}
