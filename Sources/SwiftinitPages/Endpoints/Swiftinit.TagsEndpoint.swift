import HTTP
import MongoDB
import SwiftinitRender
import UnidocDB
import UnidocQueries

extension Swiftinit
{
    @frozen public
    struct TagsEndpoint
    {
        public
        let query:Unidoc.VersionsQuery
        public
        var value:Unidoc.VersionsQuery.Output?

        @inlinable public
        init(query:Unidoc.VersionsQuery)
        {
            self.query = query
            self.value = nil
        }
    }
}
extension Swiftinit.TagsEndpoint:Mongo.PipelineEndpoint, Mongo.SingleOutputEndpoint
{
    @inlinable public static
    var replica:Mongo.ReadPreference { .nearest }
}
extension Swiftinit.TagsEndpoint:HTTP.ServerEndpoint
{
    public consuming
    func response(as format:Swiftinit.RenderFormat) -> HTTP.ServerResponse
    {
        guard
        let output:Unidoc.VersionsQuery.Output = self.value
        else
        {
            return .error("Query for endpoint '\(Self.self)' returned no outputs!")
        }

        let view:Swiftinit.ViewMode = format.secure
            ? .init(package: output.package, user: output.user)
            : .admin

        let tags:Swiftinit.TagsTable

        switch self.query.filter
        {
        case .tags(limit: let limit, page: _, beta: let beta):
            let list:[Unidoc.VersionsQuery.Tag] = beta ? output.prereleases : output.releases

            tags = .init(
                package: output.package.symbol,
                tagged: list,
                view: view,
                more: list.count == limit)

        case .none(limit: let limit):
            var prereleases:ArraySlice<Unidoc.VersionsQuery.Tag> = output.prereleases[...]
            var releases:ArraySlice<Unidoc.VersionsQuery.Tag> = output.releases[...]

            //  Merge the two pre-sorted arrays into a single sorted array.
            var list:[Unidoc.VersionsQuery.Tag] = []
                list.reserveCapacity(prereleases.count + releases.count)
            while
                let prerelease:Unidoc.VersionsQuery.Tag = prereleases.first,
                let release:Unidoc.VersionsQuery.Tag = releases.first
            {
                if  release.edition.patch < prerelease.edition.patch
                {
                    list.append(prerelease)
                    prereleases.removeFirst()
                }
                else
                {
                    list.append(release)
                    releases.removeFirst()
                }
            }

            //  Append any remaining items.
            list += prereleases
            list += releases

            tags = .init(
                package: output.package.symbol,
                tagless: output.tagless,
                tagged: list,
                view: view,
                more: output.releases.count == limit)
        }

        let page:Swiftinit.TagsPage = .init(package: output.package,
            aliases: output.aliases,
            realm: output.realm,
            table: tags,
            shown: self.query.filter)

        return .ok(page.resource(format: format))
    }
}
