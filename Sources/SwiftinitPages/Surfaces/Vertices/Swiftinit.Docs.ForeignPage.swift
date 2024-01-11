import HTML
import LexicalPaths
import MarkdownRendering
import Symbols
import Unidoc
import UnidocRecords
import URI

extension Swiftinit.Docs
{
    struct ForeignPage
    {
        let context:IdentifiablePageContext<Swiftinit.Vertices>

        let canonical:CanonicalVersion?

        private
        let vertex:Unidoc.ForeignVertex
        private
        let groups:Swiftinit.GroupLists

        private
        let stem:Unidoc.StemComponents

        init(_ context:IdentifiablePageContext<Swiftinit.Vertices>,
            canonical:CanonicalVersion?,
            vertex:Unidoc.ForeignVertex,
            groups:Swiftinit.GroupLists) throws
        {
            self.context = context
            self.canonical = canonical
            self.vertex = vertex
            self.groups = groups

            self.stem = try .init(vertex.stem)
        }
    }
}
extension Swiftinit.Docs.ForeignPage
{
    private
    var demonym:Swiftinit.DeclDemonym
    {
        .init(phylum: self.vertex.phylum, kinks: self.vertex.kinks)
    }
}
extension Swiftinit.Docs.ForeignPage:Swiftinit.RenderablePage
{
    var title:String { "\(self.stem.last) (ext) · \(self.volume.title) Documentation" }

    var description:String?
    {
        """
        \(self.stem.last), \(self.demonym.phrase) from \(self.stem.namespace), has extensions \
        available in the package \(self.volume.title)").
        """
    }
}
extension Swiftinit.Docs.ForeignPage:Swiftinit.StaticPage
{
    var location:URI { Swiftinit.Docs[self.volume, self.vertex.route] }
}
extension Swiftinit.Docs.ForeignPage:Swiftinit.ApplicationPage
{
    typealias Navigator = HTML.Logo
}
extension Swiftinit.Docs.ForeignPage:Swiftinit.VertexPage
{
    var sidebar:Swiftinit.Sidebar<Swiftinit.Docs>? { .package(volume: self.volume) }

    func main(_ main:inout HTML.ContentEncoder, format:Swiftinit.RenderFormat)
    {
        main[.section, { $0.class = "introduction" }]
        {
            $0[.div, { $0.class = "eyebrows" }]
            {
                $0[.span] { $0.class = "phylum" } = "Extension (\(self.demonym.title))"
                $0[.span] { $0.class = "domain" } = self.context.domain
            }

            $0[.nav] { $0.class = "breadcrumbs" } = self.context.vector(self.vertex.scope,
                display: self.stem.scope)

            $0[.h1] = "\(self.stem.last) (ext)"
        }

        let extendee:HTML.Link<UnqualifiedPath>? = self.context.link(decl: self.vertex.extendee)
        if  let other:Unidoc.VolumeMetadata = self.context[self.vertex.extendee.edition]
        {
            main[.section, { $0.class = "notice extendee" }]
            {
                $0[.p]
                {
                    $0 += "You’re viewing third-party extensions to "
                    $0[.code] = extendee
                    $0 += ", \(self.demonym.phrase) from "

                    $0[.a]
                    {
                        $0.href = "\(Swiftinit.Docs[other])"
                    } = other.symbol.package == .swift
                        ? "the Swift standard library"
                        : other.title

                    $0 += "."
                }

                $0[.p]
                {
                    $0 += """
                    You can also read the documentation for
                    """
                    $0[.code] = extendee
                    $0 += " itself."
                }
            }
        }

        main[.section, { $0.class = "declaration" }]
        {
            $0[.pre]
            {
                $0[.code]
                {
                    $0[.span] { $0.highlight = .keyword } = "extension"
                    $0 += " "
                    $0[link: extendee?.target] { $0.class = "extendee" } = self.stem.last
                }
            }
        }

        main += self.groups
    }
}
