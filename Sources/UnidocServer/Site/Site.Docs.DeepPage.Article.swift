import HTML
import MarkdownRendering
import UnidocRecords
import Unidoc
import URI

extension Site.Docs.DeepPage
{
    struct Article
    {
        private
        let inliner:Inliner
        private
        let path:QualifiedPath

        let master:Record.Master.Article
        let groups:[Record.Group]


        init(_ inliner:Inliner, master:Record.Master.Article, groups:[Record.Group])
        {
            self.master = master
            self.groups = groups
            self.inliner = inliner
            self.path = .init(splitting: self.master.stem)
        }
    }
}
extension Site.Docs.DeepPage.Article
{
    var trunk:Record.Trunk
    {
        self.inliner.zones.principal.trunk
    }

    var location:URI
    {
        .init(article: self.master, in: self.trunk)
    }

    var title:String?
    {
        "\(self.trunk.display ?? "\(self.trunk.package)") Documentation"
    }
}
extension Site.Docs.DeepPage.Article:HyperTextOutputStreamable
{
    public static
    func += (html:inout HTML.ContentEncoder, self:Self)
    {
        html[.section, { $0.class = "introduction" }]
        {
            $0[.div, { $0.class = "eyebrows" }]
            {
                $0[.span] { $0.class = "phylum" } = "Article"

                $0[.span, { $0.class = "module" }]
                {
                    $0[link: self.inliner.url(self.master.culture)] = self.path.namespace

                    $0[.span, { $0.class = "culture" }]
                    {
                        $0[.span] { $0.class = "version" } = self.trunk.version
                    }
                }
            }

            $0[.h1] = self.master.headline.safe

            $0 ?= self.master.overview.map(self.inliner.passage(_:))

            if  let file:Unidoc.Scalar = self.master.file
            {
                $0 ?= self.inliner.link(file: file)
            }
        }
        html[.section, { $0.class = "details" }] =
            self.master.details.map(self.inliner.passage(_:))
    }
}
