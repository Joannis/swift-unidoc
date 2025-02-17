import GitHubAPI
import GitHubClient
import HTTP
import MongoDB
import UnidocDB

extension Swiftinit
{
    struct LoginEndpoint:Sendable
    {
        let state:String
        let code:String

        init(state:String, code:String)
        {
            self.state = state
            self.code = code
        }
    }
}
extension Swiftinit.LoginEndpoint:InteractiveEndpoint
{
    func load(from server:borrowing Swiftinit.Server,
        with cookies:Swiftinit.Cookies,
        as format:Swiftinit.RenderFormat) async throws -> HTTP.ServerResponse?
    {
        let github:GitHub.Client<GitHub.OAuth>
        if  let oauth:GitHub.OAuth = server.github?.oauth
        {
            github = .oauth(oauth,
                threads: server.context.threads,
                niossl: server.context.niossl)
        }
        else
        {
            return nil
        }

        guard case self.state? = cookies.login
        else
        {
            return .resource("Authentication failed: state mismatch", status: 400)
        }

        let registration:Swiftinit.RegistrationEndpoint
        do
        {
            let access:GitHub.OAuth.Credentials = try await github.exchange(code: self.code)
            registration = .init(token: access.token)
        }
        catch is GitHub.Client<GitHub.OAuth>.AuthenticationError
        {
            return .unauthorized("Authentication failed")
        }
        catch
        {
            throw error
        }

        return try await registration.load(from: server, with: cookies, as: format)
    }
}
