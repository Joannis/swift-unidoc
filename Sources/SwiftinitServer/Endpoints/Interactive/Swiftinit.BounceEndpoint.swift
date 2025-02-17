import GitHubAPI
import GitHubClient
import HTTP
import SwiftinitPages

extension Swiftinit
{
    struct BounceEndpoint:Sendable
    {
        init()
        {
        }
    }
}
extension Swiftinit.BounceEndpoint:PublicEndpoint
{
    func load(from server:borrowing Swiftinit.Server,
        as _:Swiftinit.RenderFormat) -> HTTP.ServerResponse?
    {
        if  let oauth:GitHub.OAuth = server.github?.oauth
        {
            let page:Swiftinit.LoginPage = .init(app: oauth)
            return .ok(page.resource(format: server.format))
        }
        else
        {
            return nil
        }
    }
}
