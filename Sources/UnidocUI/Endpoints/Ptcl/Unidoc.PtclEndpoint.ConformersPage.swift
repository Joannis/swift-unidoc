import Availability
import FNV1
import HTML
import LexicalPaths
import MarkdownABI
import Signatures
import Sources
import Symbols
import Unidoc
import UnidocRecords
import URI

extension Unidoc.PtclEndpoint
{
    struct ConformersPage
    {
        let sidebar:Unidoc.Sidebar<Unidoc.DocsEndpoint>?

        private
        let vertex:Unidoc.DeclVertex
        private
        let halo:Unidoc.ConformingTypes

        private
        let stem:Unidoc.StemComponents

        init(sidebar:Unidoc.Sidebar<Unidoc.DocsEndpoint>?,
            vertex:Unidoc.DeclVertex,
            halo:Unidoc.ConformingTypes) throws
        {
            self.sidebar = sidebar
            self.vertex = vertex
            self.halo = halo

            self.stem = try .init(vertex.stem)
        }
    }
}
extension Unidoc.PtclEndpoint.ConformersPage
{
    private
    var demonym:Unidoc.DeclDemonym
    {
        .init(phylum: self.vertex.phylum, kinks: self.vertex.kinks)
    }
}
extension Unidoc.PtclEndpoint.ConformersPage:Unidoc.RenderablePage
{
    var title:String
    {
        "\(self.stem.last) (Conforming Types) · \(self.volume.title) Documentation"
    }

    var description:String?
    {
        """
        The protocol \(self.stem.last) has at least \(self.halo.count) \
        conforming \(self.halo.count == 1 ? "type" : "types") available.
        """
    }
}
extension Unidoc.PtclEndpoint.ConformersPage:Unidoc.StaticPage
{
    var location:URI { Unidoc.PtclEndpoint[self.volume, self.vertex.route] }
}
extension Unidoc.PtclEndpoint.ConformersPage:Unidoc.ApplicationPage
{
    typealias Navigator = HTML.Logo
}
extension Unidoc.PtclEndpoint.ConformersPage:Unidoc.VertexPage
{
    var context:Unidoc.PeripheralPageContext { self.halo.context }

    func main(_ main:inout HTML.ContentEncoder, format:Unidoc.RenderFormat)
    {
        let back:String = "\(Unidoc.DocsEndpoint[self.volume, self.vertex.route])"
        let name:Substring = self.stem.last

        main[.section, { $0.class = "introduction" }]
        {
            $0[.div, { $0.class = "eyebrows" }]
            {
                $0[.span] { $0.class = "phylum" } = "Conforming types"

                $0[.span, { $0.class = "domain" }] = self.context.subdomain(self.stem.namespace,
                    namespace: self.vertex.namespace,
                    culture: self.vertex.culture)
            }

            $0[.nav] { $0.class = "breadcrumbs" } = self.context.vector(self.vertex.scope,
                display: self.stem.scope)

            $0[.h1] = name

            $0[.p]
            {
                $0 += "The protocol "
                $0[.code] { $0[.a] { $0.href = back } = name }
                switch self.halo.count
                {
                case 0:
                    $0 += " has no known conforming types available."

                case 1:
                    $0 += " has at least one known conforming type."

                case let count:
                    $0 += " has at least \(count) conforming types available"

                    if  self.halo.cultures > 1
                    {
                        $0 += " across \(self.halo.cultures) modules."
                    }
                    else
                    {
                        $0 += "."
                    }
                }
            }
        }

        main[.section] { $0.class = "notice canonical" } = self.context.canonical

        main += self.halo
    }
}
