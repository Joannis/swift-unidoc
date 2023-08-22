import HTML
import LexicalPaths
import MarkdownRendering
import Signatures
import Unidoc
import UnidocRecords

extension Inliner
{
    struct Groups
    {
        let inliner:Inliner

        private
        let requirements:[Unidoc.Scalar]?
        private
        let superforms:[Unidoc.Scalar]?

        private
        let extensions:[Record.Group.Extension]
        private
        let automatic:[Record.Group.Automatic]
        private
        let topics:[Record.Group.Topic]

        private
        let bias:Unidoc.Scalar?
        private
        let mode:Mode?

        private
        init(_ inliner:Inliner,
            requirements:[Unidoc.Scalar]?,
            superforms:[Unidoc.Scalar]?,
            extensions:[Record.Group.Extension],
            automatic:[Record.Group.Automatic],
            topics:[Record.Group.Topic],
            bias:Unidoc.Scalar?,
            mode:Mode?)
        {
            self.inliner = inliner

            self.requirements = requirements
            self.superforms = superforms
            self.extensions = extensions
            self.automatic = automatic
            self.topics = topics
            self.bias = bias
            self.mode = mode
        }
    }
}
extension Inliner.Groups
{
    init(_ inliner:__owned Inliner,
        requirements:__owned [Unidoc.Scalar] = [],
        superforms:__owned [Unidoc.Scalar] = [],
        generics:__shared [GenericParameter] = [],
        groups:__shared [Record.Group],
        bias:Unidoc.Scalar? = nil,
        mode:Mode? = nil)
    {
        let generics:Generics = .init(generics)

        let libraries:[Partisanship: [Record.Group.Extension]]
        let automatic:[Record.Group.Automatic]
        let topics:[Record.Group.Topic]

        (libraries, automatic, topics) = groups.reduce(into: ([:], [], []) as
        (
            libraries:[Partisanship: [Record.Group.Extension]],
            automatic:[Record.Group.Automatic],
            topics:[Record.Group.Topic]
        ))
        {
            switch $1
            {
            case .extension(let `extension`):
                if  let party:Partisanship = .of(extension: `extension`.id,
                        zones: inliner.zones)
                {
                    $0.libraries[party, default: []].append(`extension`)
                }

            case .automatic(let automatic):
                $0.automatic.append(automatic)

            case .topic(let topic):
                $0.topics.append(topic)
            }
        }

        self.init(inliner,
            requirements: requirements.isEmpty ? nil : requirements,
            superforms: superforms.isEmpty ? nil : superforms,
            extensions: libraries.sorted
            {
                //  Sort libraries by partisanship, first-party first, then third-party
                //  by package identifier.
                $0.key < $1.key
            }
                .flatMap
            {
                //  Within each library, sort extensions by genericness, then by culture.
                generics.partition(extensions: $0.value)
            },
            automatic: automatic.sorted { $0.id < $1.id },
            topics: topics.sorted { $0.id < $1.id },
            bias: bias,
            mode: mode)
    }
}
extension Inliner.Groups
{
    private
    func header(for extension:Record.Group.Extension) -> Inliner.ExtensionHeader
    {
        let display:String
        switch (self.bias, self.bias?.zone)
        {
        case (`extension`.culture?, _): display = "Citizens in "
        case (_, `extension`.id.zone?): display = "Available in "
        case (_,                    _): display = "Extension in "
        }

        return .init(self.inliner,
            display: display,
            culture: `extension`.culture,
            where: `extension`.conditions)
    }

    private
    func list(_ scalars:__owned [Unidoc.Scalar], under heading:String? = nil) -> List?
    {
        if  scalars.isEmpty
        {
            return nil
        }
        else
        {
            return .init(self.inliner, heading: heading, scalars: scalars)
        }
    }
}
extension Inliner.Groups:HyperTextOutputStreamable
{
    static
    func += (html:inout HTML.ContentEncoder, self:Self)
    {
        for group:Record.Group.Automatic in self.automatic
        {
            html[.section, { $0.class = "group automatic" }]
            {
                $0[.h2] = self.mode == .meta ? "Modules" : "See Also"
                $0[.ul]
                {
                    for member:Unidoc.Scalar in group.members
                    {
                        $0 ?= self.inliner.card(member)
                    }
                }
            }
        }
        for group:Record.Group.Topic in self.topics
        {
            html[.section, { $0.class = "group topic" }]
            {
                if  let principal:Unidoc.Scalar = self.inliner.masters.principal,
                        group.members.contains(.scalar(principal))
                {
                    $0[.h2] = "See Also"
                }
                else
                {
                    $0 ?= group.overview.map(self.inliner.passage(overview:))
                }
                $0[.ul]
                {
                    for member:Record.Link in group.members
                    {
                        switch member
                        {
                        case .scalar(let scalar):   $0 ?= self.inliner.card(scalar)
                        case .text(let text):       $0[.li] { $0[.span] { $0[.code] = text } }
                        }
                    }
                }
            }
        }

        guard case .decl(let phylum, let kinks)? = self.mode
        else
        {
            return
        }

        if  let superforms:[Unidoc.Scalar] = self.superforms
        {
            html[.section, { $0.class = "group superforms" }]
            {
                if      kinks[is: .required]
                {
                    $0[.h2] = "Restates"
                }
                else if kinks[is: .intrinsicWitness]
                {
                    $0[.h2] = "Implements"
                }
                else if kinks[is: .override]
                {
                    $0[.h2] = "Overrides"
                }
                else if case .class = phylum
                {
                    $0[.h2] = "Superclasses"
                }
                else
                {
                    $0[.h2] = "Supertypes"
                }

                $0[.ul]
                {
                    for superform:Unidoc.Scalar in superforms
                    {
                        $0 ?= self.inliner.card(superform)
                    }
                }
            }
        }

        if  let requirements:[Unidoc.Scalar] = self.requirements
        {
            html[.section, { $0.class = "group requirements" }]
            {
                $0[.h2] = "Requirements"
                $0[.ul]
                {
                    for requirement:Unidoc.Scalar in requirements
                    {
                        $0 ?= self.inliner.card(requirement)
                    }
                }
            }
        }

        for group:Record.Group.Extension in self.extensions
        {
            html[.section, { $0.class = "group extension" }]
            {
                $0 += self.header(for: group)

                $0 ?= self.list(group.conformances, under: "Conformances")
                $0 ?= self.list(group.nested, under: "Members")
                $0 ?= self.list(group.features, under: "Features")

                switch phylum
                {
                case .protocol:
                    $0 ?= self.list(group.subforms, under: "Subtypes")

                case .class:
                    $0 ?= self.list(group.subforms, under: "Subclasses")

                case _:
                    if  kinks[is: .required]
                    {
                        let (restatements, witnesses):([Unidoc.Scalar], [Unidoc.Scalar]) =
                            group.subforms.reduce(into: ([], []))
                        {
                            if  case true? =
                                self.inliner.masters[$1]?.decl?.kinks[is: .intrinsicWitness]
                            {
                                $0.1.append($1)
                            }
                            else
                            {
                                $0.0.append($1)
                            }
                        }

                        $0 ?= self.list(restatements, under: "Restated By")
                        $0 ?= self.list(witnesses, under: "Default Implementations")
                    }
                    else
                    {
                        $0 ?= self.list(group.subforms, under: "Overridden By")
                    }
                }
            }
        }
    }
}
