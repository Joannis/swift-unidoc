import HTTP
import MD5
import ModuleGraphs
import MongoDB
import UnidocAnalysis
import UnidocDB
import UnidocPages
import UnidocRecords
import UnidocSelectors
import URI

extension Server.Operation
{
    struct SiteMap:Sendable
    {
        let package:PackageIdentifier

        let uri:URI
        let tag:MD5?

        init(package:PackageIdentifier, uri:URI, tag:MD5?)
        {
            self.package = package
            self.uri = uri
            self.tag = tag
        }
    }
}
extension Server.Operation.SiteMap:InteractiveOperation
{
    var statisticalType:WritableKeyPath<ServerTour.Stats.ByType, Int>
    {
        \.siteMap
    }
}
extension Server.Operation.SiteMap:UnrestrictedOperation
{
    func load(from server:Server.State) async throws -> ServerResponse?
    {
        let session:Mongo.Session = try await .init(from: server.db.sessions)

        guard
        let siteMap:Volume.SiteMap<PackageIdentifier> = try await server.db.unidoc.siteMap(
            package: self.package,
            with: session)
        else
        {
            return nil
        }

        let prefix:String = "https://swiftinit.org/\(Site.Docs.root)/\(self.package)"
        var string:String = ""
        var i:Int = siteMap.lines.startIndex

        while let j:Int = siteMap.lines[i...].firstIndex(of: 0x0A)
        {
            defer { i = siteMap.lines.index(after: j) }

            let shoot:Volume.Shoot = .deserialize(from: siteMap.lines[i..<j])
            var uri:URI = [] ; uri.path += shoot.stem ; uri["hash"] = shoot.hash?.description

            string += "\(prefix)\(uri)\n"
        }

        var resource:ServerResource = .init(content: .string(string),
            type: .text(.plain, charset: .utf8))

        resource.optimize(tag: self.tag)

        return .ok(resource)
    }
}
