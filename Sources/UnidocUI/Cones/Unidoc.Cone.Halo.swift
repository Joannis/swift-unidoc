import HTML
import LexicalPaths
import MarkdownRendering
import Signatures
import SymbolGraphs
import Symbols
import Unidoc
import UnidocRecords

extension Unidoc.Cone
{
    struct Halo
    {
        let context:Unidoc.InternalPageContext

        private
        var uncategorized:[Unidoc.Scalar]

        private
        var requirements:[Unidoc.Scalar]
        private
        var inhabitants:[Unidoc.Scalar]
        private
        var superforms:[Unidoc.Scalar]
        private
        var curation:[Unidoc.Scalar]
        private
        var products:[Unidoc.Scalar]
        private
        var modules:[Unidoc.Scalar]

        private
        var _topics:[Unidoc.TopicGroup]
        private
        var extensions:[Unidoc.ExtensionGroup]

        private(set)
        var peerConstraints:[GenericConstraint<Unidoc.Scalar?>]
        private(set)
        var peerList:[Unidoc.Scalar]

        private
        let decl:Phylum.DeclFlags?
        private
        let bias:Unidoc.Bias

        private
        init(_ context:Unidoc.InternalPageContext,
            decl:Phylum.DeclFlags?,
            bias:Unidoc.Bias)
        {
            self.context = context

            self.uncategorized = []
            self.requirements = []
            self.inhabitants = []
            self.superforms = []
            self.curation = []
            self.products = []
            self.modules = []

            self._topics = []
            self.extensions = []
            self.peerConstraints = []
            self.peerList = []

            self.decl = decl
            self.bias = bias
        }
    }
}
extension Unidoc.Cone.Halo
{
    init(_ context:Unidoc.InternalPageContext,
        curated:consuming Set<Unidoc.Scalar>,
        groups:borrowing [Unidoc.AnyGroup],
        apex:borrowing Unidoc.DeclVertex) throws
    {
        self.init(context, decl: apex.flags, bias: apex.bias)

        self.requirements = apex._requirements
        self.superforms = apex.superforms

        try self.organize(groups: groups,
            excluding: consume curated,
            container: apex.peers,
            generics: .init(apex.signature.generics.parameters))
    }

    init(_ context:Unidoc.InternalPageContext,
        curated:consuming Set<Unidoc.Scalar>,
        groups:borrowing [Unidoc.AnyGroup],
        decl:Phylum.DeclFlags? = nil,
        bias:Unidoc.Bias) throws
    {
        self.init(context, decl: decl, bias: bias)

        try self.organize(groups: groups, excluding: consume curated)
    }
}
extension Unidoc.Cone.Halo
{
    private mutating
    func organize(groups:[Unidoc.AnyGroup],
        excluding curated:consuming Set<Unidoc.Scalar>,
        container:Unidoc.Group? = nil,
        generics:Generics = .init([])) throws
    {
        var extensions:[(Unidoc.ExtensionGroup, Partisanship, Generality)] = []
        for group:Unidoc.AnyGroup in groups
        {
            switch group
            {
            case .extension(let group):
                if  case group.id? = container
                {
                    self.peerConstraints = group.constraints
                    self.peerList = group.nested
                    continue
                }

                let partisanship:Partisanship = self.context[secondary: group.id.edition]
                    .map
                {
                    .third($0.symbol.package)
                } ?? .first

                let genericness:Generality = group.constraints.isEmpty ?
                    .unconstrained : generics.count(substituting: group.constraints) > 0 ?
                    .constrained :
                    .concretized

                extensions.append((group, partisanship, genericness))

            case .intrinsic(let group):
                if  case group.id? = container
                {
                    self.peerList = group.items
                    continue
                }

                switch self.decl?.phylum
                {
                case .protocol?:
                    self.requirements += group.items

                case .enum?:
                    self.inhabitants += group.items

                default:
                    throw Unidoc.GroupTypeError.reject(.intrinsic(group))
                }

            case .curator(let group):
                guard
                let first:Unidoc.Scalar = group.items.first,
                let plane:SymbolGraph.Plane = first.plane
                else
                {
                    continue
                }

                //  Guess what kind of polygon this is by looking at the bit pattern of its
                //  first vertex.
                switch plane
                {
                case .product:
                    self.products += group.items

                case .module:
                    self.modules += group.items

                default:
                    if  case nil = group.scope
                    {
                        self.curation += group.items
                        //  We’re not filtering these, so we need to remove these members from
                        //  any other groups that might also contain them.
                        //
                        //  This logic probably needs to be revisited.
                        curated.formUnion(group.items)
                    }
                    else
                    {
                        self.uncategorized += group.items
                    }
                }

            case ._topic(let group):
                for case .scalar(let scalar) in group.members
                {
                    curated.insert(scalar)
                }

                self._topics.append(group)

            case let unexpected:
                throw Unidoc.GroupTypeError.reject(unexpected)
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

        //  Prevent the currently-shown page from appearing in the “See Also” section.
        let apex:Unidoc.Scalar = self.context.id

        curated.insert(apex)
        self.curation.removeAll { $0 == apex }

        self.extensions = extensions.map { $0.0.subtracting(curated) }

        self.uncategorized.removeAll(where: curated.contains(_:))
        self.requirements.removeAll(where: curated.contains(_:))
        self.inhabitants.removeAll(where: curated.contains(_:))
        self.superforms.removeAll(where: curated.contains(_:))
        self.products.removeAll(where: curated.contains(_:))
        self.modules.removeAll(where: curated.contains(_:))
        self.peerList.removeAll(where: curated.contains(_:))

        self._topics.sort { $0.id < $1.id }
    }
}
extension Unidoc.Cone.Halo:HTML.OutputStreamable
{
    static
    func += (html:inout HTML.ContentEncoder, self:Self)
    {
        var other:Unidoc.TopicGroup? = nil
        for group:Unidoc.TopicGroup in self._topics
        {
            if  group.members.contains(.scalar(self.context.id))
            {
                guard group.members.count > 1
                else
                {
                    //  This is a topic group that contains this page only.
                    //  A “See Also” section is not necessary.
                    continue
                }

                other = group
            }
            else
            {
                //  This is a topic group that doesn’t contain this page. It is not a “See Also”
                //  section, and we should render any caption associated with it.
                html[.section]
                {
                    $0.class = "group topic"
                } = Unidoc._LegacyTopic.init(self.context,
                    caption: group.overview,
                    members: group.members)
            }
        }

        if  let body:Unidoc.SegregatedBody = .init(self.context, group: self.uncategorized)
        {
            //  This is an uncategorized section, so let’s categorize it.
            html[.section]
            {
                $0.class = "group segregated"
            } = Unidoc.CollapsibleSection<Unidoc.SegregatedBody>.init(
                heading: .uncategorized,
                content: body)
        }

        if  let modules:Unidoc.IntegratedList = .init(self.context, items: self.modules)
        {
            html[.section]
            {
                $0.class = "group automatic"
            } = Unidoc.CollapsibleSection<Unidoc.IntegratedList>.init(
                heading: self.bias == .package ? .allModules : .otherModules,
                content: modules)
        }
        if  let products:Unidoc.IntegratedList = .init(self.context, items: self.products)
        {
            html[.section]
            {
                $0.class = "group automatic"
            } = Unidoc.CollapsibleSection<Unidoc.IntegratedList>.init(
                heading: self.bias == .package ? .allProducts : .otherProducts,
                content: products)
        }

        if  let decl:Phylum.DeclFlags = self.decl,
            let body:Unidoc.SegregatedList = .init(self.context, group: self.superforms)
        {
            let heading:AutomaticHeading

            if      decl.kinks[is: .required]
            {
                heading = .restatesRequirements
            }
            else if decl.kinks[is: .intrinsicWitness]
            {
                heading = .implementsRequirements
            }
            else if decl.kinks[is: .override]
            {
                heading = .overrides
            }
            else if case .class = decl.phylum
            {
                heading = .superclasses
            }
            else
            {
                heading = .supertypes
            }

            html[.section]
            {
                $0.class = "group superforms"
            } = Unidoc.CollapsibleSection<Unidoc.SegregatedList>.init(
                heading: heading,
                content: body)
        }
        if  let body:Unidoc.SegregatedList = .init(self.context, group: self.inhabitants)
        {
            html[.section]
            {
                $0.class = "group inhabitants"
            } = Unidoc.CollapsibleSection<Unidoc.SegregatedList>.init(
                heading: .allCases,
                content: body)
        }
        if  let body:Unidoc.SegregatedBody = .init(self.context, group: self.requirements)
        {
            html[.section]
            {
                $0.class = "group segregated requirements"
            } = Unidoc.CollapsibleSection<Unidoc.SegregatedBody>.init(
                heading: .allRequirements,
                content: body)
        }

        let extensionsEmpty:Bool = self.extensions.allSatisfy(\.isEmpty)

        if  let curation:Unidoc.IntegratedList = .init(self.context, items: self.curation)
        {
            let last:Bool = self.peerList.isEmpty && extensionsEmpty

            html[.section]
            {
                $0.class = "group topic"
            } = Unidoc.CollapsibleSection<Unidoc.IntegratedList>.init(
                heading: .seeAlso,
                content: curation,
                window: last ? nil : 12 ... 12)
        }
        else if
            let other:Unidoc.TopicGroup
        {
            let last:Bool = self.peerList.isEmpty && extensionsEmpty

            html[.section]
            {
                $0.class = "group topic"
            } = Unidoc.CollapsibleSection<Unidoc._LegacyTopic>.init(
                heading: .seeAlso,
                content: .init(self.context, members: other.members),
                window: last ? nil : 12 ... 12)
        }

        guard
        let decl:Phylum.DeclFlags = self.decl
        else
        {
            //  The rest of the sections are only relevant for declarations.
            return
        }

        if  case .case = decl.phylum,
            let peers:Unidoc.SegregatedList = .init(self.context, group: self.peerList)
        {
            html[.section]
            {
                $0.class = "group sisters"
            } = Unidoc.CollapsibleSection<Unidoc.SegregatedList>.init(
                heading: .otherCases,
                content: peers,
                window: extensionsEmpty ? nil : 12 ... 12)
        }
        else if
            let peers:Unidoc.SegregatedBody = .init(self.context, group: self.peerList)
        {
            html[.section]
            {
                $0.class = "group segregated sisters"
            } = Unidoc.CollapsibleSection<Unidoc.SegregatedBody>.init(
                heading: decl.kinks[is: .required] ? .otherRequirements : .otherMembers,
                content: peers,
                //  If there are 8–12 members, and this is not the last section, this section
                //  will be collapsible, but open by default.
                window: extensionsEmpty ? nil : 8 ... 12)
        }

        for group:Unidoc.ExtensionGroup in self.extensions
        {
            html[.section]
            {
                $0.class = "group segregated extension"
            } = Unidoc.ExtensionSection.init(self.context,
                group: group,
                decl: decl,
                bias: self.bias)
        }
    }
}
