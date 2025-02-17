import HTTP
import HTTPServer
import MongoDB
import Unidoc
import UnidocDB
import UnidocRecords

extension Swiftinit
{
    /// Queues one or more editions for uplinking. The uplinking process itself is asynchronous.
    struct GraphActionEndpoint:Sendable
    {
        let queue:Unidoc.DB.Snapshots.QueueAction
        let uri:String?

        init(queue:Unidoc.DB.Snapshots.QueueAction, uri:String? = nil)
        {
            self.queue = queue
            self.uri = uri
        }
    }
}
extension Swiftinit.GraphActionEndpoint:RestrictedEndpoint
{
    func load(from server:borrowing Swiftinit.Server) async throws -> HTTP.ServerResponse?
    {
        let session:Mongo.Session = try await .init(from: server.db.sessions)
        try await session.update(database: server.db.unidoc.id, with: self.queue)
        return .redirect(.see(other: self.uri ?? "/admin"))
    }
}
