import HTML
import MarkdownRendering
import ModuleGraphs
import UnidocRecords
import Unidoc
import URI

extension Site.Docs
{
    struct Culture
    {
        let inliner:Inliner

        private
        let master:Record.Master.Culture
        private
        let groups:[Record.Group]

        init(_ inliner:Inliner, master:Record.Master.Culture, groups:[Record.Group])
        {
            self.inliner = inliner
            self.master = master
            self.groups = groups
        }
    }
}
extension Site.Docs.Culture
{
    var zone:Record.Zone
    {
        self.inliner.zones.principal
    }
}
extension Site.Docs.Culture:FixedPage
{
    var location:URI { Site.Docs[self.zone, self.master.shoot] }

    var title:String
    {
        """
        \(self.master.module.name) - \
        \(self.zone.display ?? "\(self.zone.package)") Documentation
        """
    }

    func emit(main:inout HTML.ContentEncoder)
    {
        let groups:Inliner.Groups = .init(inliner,
            groups: self.groups,
            bias: self.master.id)

        main[.section, { $0.class = "introduction" }]
        {
            $0[.div, { $0.class = "eyebrows" }]
            {
                $0[.span] { $0.class = "phylum" } = "Module"
                $0[.span] { $0.class = "version" } = self.zone.version
            }

            $0[.h1] = self.master.module.name

            $0 ?= (self.master.overview?.markdown).map(self.inliner.passage(_:))

            if  let readme:Unidoc.Scalar = self.master.readme
            {
                $0 ?= self.inliner.link(file: readme)
            }
        }

        main[.section, { $0.class = "declaration" }]
        {
            $0[.pre]
            {
                $0[.code]
                {
                    $0[.span] { $0.highlight = .keyword } = "import"
                    $0 += " "
                    $0[.span] { $0.highlight = .identifier } = self.master.module.id
                }
            }
        }

        main[.section] { $0.class = "details" } =
            (self.master.details?.markdown).map(self.inliner.passage(_:))

        main += groups
    }
}
