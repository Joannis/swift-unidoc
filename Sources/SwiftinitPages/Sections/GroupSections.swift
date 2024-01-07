import HTML
import LexicalPaths
import MarkdownRendering
import Signatures
import SymbolGraphs
import Unidoc
import UnidocRecords

struct GroupSections
{
    let context:IdentifiablePageContext<Unidoc.Scalar>

    private
    let requirements:[Unidoc.Scalar]?
    private
    let superforms:[Unidoc.Scalar]?

    private
    var conformers:[Unidoc.ConformerGroup]
    private
    var extensions:[Unidoc.ExtensionGroup]
    private
    var topics:[Unidoc.TopicGroup]
    private
    var other:[(AutomaticHeading, [Unidoc.Scalar])]

    private(set)
    var peers:Unidoc.ExtensionGroup?

    private
    let bias:Unidoc.Scalar?
    private
    let mode:Mode?

    private
    init(_ context:IdentifiablePageContext<Unidoc.Scalar>,
        requirements:[Unidoc.Scalar]?,
        superforms:[Unidoc.Scalar]?,
        conformers:[Unidoc.ConformerGroup] = [],
        extensions:[Unidoc.ExtensionGroup] = [],
        topics:[Unidoc.TopicGroup] = [],
        other:[(AutomaticHeading, [Unidoc.Scalar])] = [],
        peers:Unidoc.ExtensionGroup? = nil,
        bias:Unidoc.Scalar?,
        mode:Mode?)
    {
        self.context = context

        self.requirements = requirements
        self.superforms = superforms
        self.conformers = conformers
        self.extensions = extensions
        self.topics = topics
        self.other = other
        self.peers = peers
        self.bias = bias
        self.mode = mode
    }
}
extension GroupSections
{
    init(_ context:IdentifiablePageContext<Unidoc.Scalar>,
        organizing groups:/*consuming*/ [Unidoc.AnyGroup],
        vertex:borrowing Unidoc.DeclVertex? = nil,
        bias:Unidoc.Scalar? = nil,
        mode:Mode? = nil)
    {
        let container:Unidoc.Group?
        let generics:Generics
        if  let vertex:Unidoc.DeclVertex = copy vertex
        {
            self.init(consume context,
                requirements: vertex.requirements.isEmpty ? nil : vertex.requirements,
                superforms: vertex.superforms.isEmpty ? nil : vertex.superforms,
                bias: bias,
                mode: mode)

            container = vertex.extension
            generics = .init(vertex.signature.generics.parameters)
        }
        else
        {
            self.init(consume context,
                requirements: nil,
                superforms: nil,
                bias: bias,
                mode: mode)

            container = nil
            generics = .init([])
        }

        var extensions:[(Unidoc.ExtensionGroup, Partisanship, Genericness)] = []
        var curated:Set<Unidoc.Scalar> = [self.context.id]

        for group:Unidoc.AnyGroup in groups
        {
            switch group
            {
            case .conformer(let group):
                self.conformers.append(group)

            case .extension(let group):
                if  case group.id? = container
                {
                    self.peers = group
                    continue
                }

                let partisanship:Partisanship = self.context.volumes.secondary[group.id.edition]
                    .map
                {
                    .third($0.symbol.package)
                } ?? .first

                let genericness:Genericness = group.constraints.isEmpty ?
                    .unconstrained : generics.count(substituting: group.constraints) > 0 ?
                    .constrained :
                    .concretized

                extensions.append((group, partisanship, genericness))

            case .polygonal(let group):
                guard
                let first:Unidoc.Scalar = group.members.first,
                let plane:SymbolGraph.Plane = first.plane
                else
                {
                    continue
                }

                if  first == self.context.id,
                    group.members.count == 1
                {
                    //  This is a polygon that contains this page only.
                    continue
                }

                //  Guess what kind of polygon this is by looking at the bit pattern of its
                //  first vertex.
                let heading:AutomaticHeading
                switch (plane, self.mode)
                {
                case (.product, .meta): heading = .allProducts
                case (.product, _):     heading = .otherProducts
                case (.module, .meta):  heading = .allModules
                case (.module, _):      heading = .otherModules
                default:                heading = .miscellaneous
                }

                self.other.append((heading, group.members))

            case .topic(let group):
                for case .scalar(let scalar) in group.members
                {
                    curated.insert(scalar)
                }

                self.topics.append(group)
            }
        }

        extensions.sort
        {
            //  Sort libraries by partisanship, first-party first, then third-party
            //  by package identifier.
            //  Then, break ties by extension culture. Module numbers are
            //  lexicographically ordered according to the package’s internal dependency
            //  graph, so the library with the lowest module number will always be the
            //  current culture, if it is present.
            //  Then, break ties by genericness. Generic extensions come first, concrete
            //  extensions come last.
            //  Finally, break ties by extension id. This is arbitrary, but we usually try
            //  to assign id numbers such that the extensions with the fewest constraints
            //  come first.
            ($0.1, $0.0.culture.citizen, $0.2, $0.0.id) <
            ($1.1, $1.0.culture.citizen, $1.2, $1.0.id)
        }

        //  No need to filter the conformers, as it should never appear alongside any custom
        //  curated groups.
        self.peers = self.peers.map { $0.subtracting(curated) }
        self.extensions = extensions.map { $0.0.subtracting(curated) }

        self.conformers.sort { $0.id < $1.id }
        self.topics.sort { $0.id < $1.id }
        self.other.sort { $0.0 < $1.0 }
    }
}
extension GroupSections
{
    private
    func heading(culture:Unidoc.Scalar,
        constraints:[GenericConstraint<Unidoc.Scalar?>] = []) -> ExtensionHeading
    {
        let display:String
        switch (self.bias, self.bias?.edition)
        {
        case (culture?, _):         display = "Citizens in "
        case (_, culture.edition?): display = "Available in "
        case (_,                _): display = "Extension in "
        }

        return .init(self.context, display: display, culture: culture, where: constraints)
    }
    private
    func heading(for group:Unidoc.ConformerGroup) -> ExtensionHeading
    {
        self.heading(culture: group.culture)
    }
    private
    func heading(for group:Unidoc.ExtensionGroup) -> ExtensionHeading
    {
        self.heading(culture: group.culture, constraints: group.constraints)
    }

    private
    func list(_ types:__owned [Unidoc.ConformingType]) -> Swiftinit.DenseList?
    {
        types.isEmpty ? nil : .init(self.context, members: types)
    }

    private
    func list(_ scalars:__owned [Unidoc.Scalar], under heading:String? = nil) -> GroupList?
    {
        scalars.isEmpty ? nil : .init(self.context, heading: heading, scalars: scalars)
    }
}

extension GroupSections:HTML.OutputStreamable
{
    static
    func += (html:inout HTML.ContentEncoder, self:Self)
    {
        for group:Unidoc.TopicGroup in self.topics
        {
            guard group.members.contains(.scalar(self.context.id))
            else
            {
                //  This is a topic group that doesn’t contain this page.
                //  It is not a “See Also” section, and we should render
                //  any prose associated with it.
                html[.section, { $0.class = "group topic" }]
                {
                    $0 ?= group.overview.map(self.context.prose(overview:))

                    $0[.ul]
                    {
                        for member:Unidoc.TopicMember in group.members
                        {
                            switch member
                            {
                            case .scalar(let scalar):
                                $0 ?= self.context.card(scalar)

                            case .text(let text):
                                $0[.li] { $0[.span] { $0[.code] = text } }
                            }
                        }
                    }
                }

                continue
            }

            if  group.members.count == 1
            {
                //  This is a topic group that contains this page only.
                //  A “See Also” section is not necessary.
                continue
            }

            html[.section, { $0.class = "group topic" }]
            {
                AutomaticHeading.seeAlso.window(&$0,
                    listing: group.members,
                    limit: 12)
                {
                    switch $1
                    {
                    case .scalar(let scalar):
                        $0 ?= self.context.card(scalar)

                    case .text(let text):
                        $0[.li] { $0[.span] { $0[.code] = text } }
                    }
                }
            }
        }

        for (heading, members):(AutomaticHeading, [Unidoc.Scalar]) in self.other
        {
            html[.section, { $0.class = "group automatic" }]
            {
                $0[.h2] = heading
                $0[.ul]
                {
                    for member:Unidoc.Scalar in members
                    {
                        $0 ?= self.context.card(member)
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
                let heading:AutomaticHeading

                if      kinks[is: .required]
                {
                    heading = .restatesRequirements
                }
                else if kinks[is: .intrinsicWitness]
                {
                    heading = .implementsRequirements
                }
                else if kinks[is: .override]
                {
                    heading = .overrides
                }
                else if case .class = phylum
                {
                    heading = .superclasses
                }
                else
                {
                    heading = .supertypes
                }

                $0[.h2] = heading
                $0[.ul]
                {
                    for superform:Unidoc.Scalar in superforms
                    {
                        $0 ?= self.context.card(superform)
                    }
                }
            }
        }

        if  let requirements:[Unidoc.Scalar] = self.requirements
        {
            html[.section, { $0.class = "group requirements" }]
            {
                let heading:AutomaticHeading = .allRequirements

                $0[.h2] = heading
                $0[.ul]
                {
                    for requirement:Unidoc.Scalar in requirements
                    {
                        $0 ?= self.context.card(requirement)
                    }
                }
            }
        }

        if  let peers:Unidoc.ExtensionGroup = self.peers, !peers.nested.isEmpty
        {
            html[.section, { $0.class = "group sisters" }]
            {
                AutomaticHeading.otherMembers.window(&$0,
                    listing: peers.nested,
                    limit: 12,
                    open: self.extensions.allSatisfy(\.isEmpty))
                {
                    $0 ?= self.context.card($1)
                }
            }
        }

        for group:Unidoc.ConformerGroup in self.conformers
        {
            html[.section, { $0.class = "group conformer" }]
            {
                $0 += self.heading(for: group)

                $0[.ul] = self.list(group.unconditional.map { .init(id: $0, where: []) }
                    + group.conditional)
            }
        }

        for group:Unidoc.ExtensionGroup in self.extensions where !group.isEmpty
        {
            html[.section, { $0.class = "group extension" }]
            {
                $0 += self.heading(for: group)

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
                                self.context.vertices[$1]?.decl?.kinks[is: .intrinsicWitness]
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
