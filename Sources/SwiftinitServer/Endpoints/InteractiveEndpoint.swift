import HTTP
import SwiftinitPages

protocol InteractiveEndpoint:Sendable
{
    consuming
    func load(from server:borrowing Swiftinit.Server,
        with cookies:Swiftinit.Cookies) async throws -> HTTP.ServerResponse?
}
