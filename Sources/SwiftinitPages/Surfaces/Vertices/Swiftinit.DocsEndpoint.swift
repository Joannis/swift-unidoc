import HTTP
import MongoDB
import UnidocDB
import UnidocQueries
import UnidocRecords

extension Swiftinit
{
    @frozen public
    struct DocsEndpoint:Mongo.SingleOutputEndpoint
    {
        public
        let query:Unidoc.VertexQuery<Unidoc.LookupAdjacent>
        public
        var value:Unidoc.VertexOutput?

        @inlinable public
        init(query:Unidoc.VertexQuery<Unidoc.LookupAdjacent>)
        {
            self.query = query
            self.value = nil
        }
    }
}
extension Swiftinit.DocsEndpoint:Swiftinit.VertexEndpoint, HTTP.ServerEndpoint
{
    public
    typealias VertexLayer = Swiftinit.Docs

    public static
    func response(
        vertex:consuming Unidoc.AnyVertex,
        groups:consuming [Unidoc.AnyGroup],
        tree:consuming Unidoc.TypeTree?,
        with context:IdentifiableResponseContext<VertexCache>) throws -> HTTP.ServerResponse
    {
        let resource:HTTP.Resource

        switch vertex
        {
        case .article(let vertex):
            let sidebar:Swiftinit.Sidebar<Swiftinit.Docs>? = .module(
                volume: context.page.volume,
                tree: tree)
            let groups:Swiftinit.GroupLists = try .init(context.page,
                organizing: consume groups,
                bias: .culture(vertex.culture),
                mode: nil)

            let page:Swiftinit.Docs.ArticlePage = .init(context.page,
                canonical: context.canonical,
                sidebar: sidebar,
                vertex: vertex,
                groups: groups)
            resource = page.resource(format: context.format)

        case .culture(let vertex):
            let sidebar:Swiftinit.Sidebar<Swiftinit.Docs>? = .module(
                volume: context.page.volume,
                tree: tree)
            let groups:Swiftinit.GroupLists = try .init(context.page,
                organizing: consume groups,
                bias: .culture(vertex.id), //  I AM THE CULTURE
                mode: nil)
            let page:Swiftinit.Docs.ModulePage = .init(context.page,
                canonical: context.canonical,
                sidebar: sidebar,
                vertex: vertex,
                groups: groups)
            resource = page.resource(format: context.format)

        case .decl(let vertex):
            let sidebar:Swiftinit.Sidebar<Swiftinit.Docs>? = .module(
                volume: context.page.volume,
                tree: tree)
            let groups:Swiftinit.GroupLists = try .init(context.page,
                organizing: consume groups,
                vertex: vertex,
                bias: .culture(vertex.culture),
                mode: .decl(vertex.phylum, vertex.kinks))
            let page:Swiftinit.Docs.DeclPage = try .init(context.page,
                canonical: context.canonical,
                sidebar: sidebar,
                vertex: vertex,
                groups: groups)
            resource = page.resource(format: context.format)

        case .file:
            throw Unidoc.VertexTypeError.file

        case .product(let vertex):
            let groups:Swiftinit.GroupLists = try .init(context.page,
                organizing: consume groups,
                bias: .neutral,
                mode: nil)
            let page:Swiftinit.Docs.ProductPage = .init(context.page,
                canonical: context.canonical,
                vertex: vertex,
                groups: groups)
            resource = page.resource(format: context.format)

        case .foreign(let vertex):
            let groups:Swiftinit.GroupLists = try .init(context.page,
                organizing: consume groups,
                bias: .neutral,
                mode: .decl(vertex.phylum, vertex.kinks))
            let page:Swiftinit.Docs.ForeignPage = try .init(context.page,
                canonical: context.canonical,
                vertex: vertex,
                groups: groups)
            resource = page.resource(format: context.format)

        case .global(let vertex):
            let groups:Swiftinit.GroupLists = try .init(context.page,
                organizing: consume groups,
                bias: .neutral,
                mode: .meta)
            let page:Swiftinit.Docs.PackagePage = .init(context.page,
                canonical: context.canonical,
                vertex: vertex,
                groups: groups)
            resource = page.resource(format: context.format)
        }

        return .ok(resource)
    }
}
