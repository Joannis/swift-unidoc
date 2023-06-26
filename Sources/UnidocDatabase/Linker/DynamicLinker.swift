import CodelinkResolution
import ModuleGraphs
import SymbolGraphs
import Symbols

struct DynamicLinker
{
    private
    let conformances:SymbolGraph.Table<Conformances>
    private
    let context:DynamicContext

    private
    var extensions:Extensions

    private(set)
    var diagnoses:[any DynamicDiagnosis]

    private
    init(conformances:SymbolGraph.Table<Conformances>,
        context:DynamicContext,
        extensions:Extensions)
    {
        self.conformances = conformances
        self.context = context

        self.extensions = extensions
        self.diagnoses = []
    }
}
extension DynamicLinker
{
    init(context:DynamicContext)
    {
        var extensions:Extensions = [:]
        let conformances:SymbolGraph.Table<Conformances> = context.current.graph.nodes.map
        {
            if  $1.extensions.isEmpty
            {
                return [:]
            }
            guard let scope:Scalar96 = context.current.declarations[$0]
            else
            {
                return [:]
            }

            var conformances:DynamicLinker.Conformances = [:]
            for `extension`:SymbolGraph.Extension in $1.extensions
            {
                let projected:ExtensionProjection = context.current.project(
                    extension: `extension`,
                    of: scope)

                //  we only need the conformances if the scalar has unqualified features
                if case false? = $1.scalar?.features.isEmpty
                {
                    for `protocol`:Scalar96 in projected.conformances
                    {
                        conformances[to: `protocol`].append(projected.signature)
                    }
                }

                //  It’s possible for two locally-disjoint extensions to coalesce
                //  into a single global extension due to constraint dropping...
                extensions[projected.signature].merge(with: projected)
            }

            return conformances
        }

        self.init(conformances: conformances, context: context, extensions: extensions)
    }
}
extension DynamicLinker
{
    var current:SnapshotObject { self.context.current }
}
extension DynamicLinker
{
    mutating
    func project() -> [ScalarProjection]
    {
        var scalars:[ScalarProjection] = []

        for ((c, culture), group):
            ((Int, SymbolGraph.Culture), DynamicResolutionGroup) in zip(zip(
                self.current.graph.cultures.indices,
                self.current.graph.cultures),
            self.context.groups())
        {
            let qualifier:ModuleIdentifier = self.current.graph.namespaces[c]
            let c:Scalar96 = self.current.translator[culture: c]

            for namespace:SymbolGraph.Namespace in culture.namespaces
            {
                let qualifier:ModuleIdentifier =
                    self.current.graph.namespaces[namespace.index]

                for (d, (node, conformances)):
                    (Int32, (SymbolGraph.Node, Conformances)) in zip(namespace.range, zip(
                    self.current.graph.nodes[namespace.range],
                    self.conformances[namespace.range]))
                {
                    let scope:Scalar96? = self.current.scope(of: d)

                    //  Ceremonial unwraps, should always succeed since we are only iterating
                    //  over module ranges.
                    guard   let scalar:SymbolGraph.Scalar = node.scalar,
                            let d:Scalar96 = self.current.declarations[d]
                    else
                    {
                        continue
                    }

                    for f:Int32 in scalar.features
                    {
                        if  let `protocol`:Scalar96 = self.current.scope(of: f),
                            let f:Scalar96 = self.current.declarations[f]
                        {
                            //  now that we know the address of the feature’s original
                            //  protocol, we can look up the constraints for the
                            //  conformance(s) that conceived it.
                            for conformance:ExtensionSignature in conformances[to: `protocol`]
                            {
                                self.extensions[conformance].features.append(f)
                            }
                        }
                    }
                    for s:Int32 in scalar.superforms
                    {
                        if  let s:Scalar96 = self.current.declarations[s]
                        {
                            let implicit:ExtensionSignature = .init(conditions: [],
                                culture: c,
                                scope: s)

                            self.extensions[implicit].subforms.append(d)
                        }
                    }

                    if  let article:SymbolGraph.Article<Never> = scalar.article
                    {
                        var resolver:DynamicResolver = .init(context: self.context,
                            namespace: qualifier,
                            group: group,
                            scope: scalar.phylum.scope(trimming: scalar.path))

                        resolver.link(article: article)

                        self.diagnoses += resolver.diagnoses
                    }

                    scalars.append(.init(id: d,
                        culture: c,
                        scope: scope.map { self.context.expand($0) },
                        declaration: scalar.declaration.map
                        {
                            self.current.declarations[$0]
                        }))
                }
            }
            if  let articles:ClosedRange<Int32> = culture.articles
            {
                for article:SymbolGraph.Article<String> in self.current.graph.articles[articles]
                {
                    var resolver:DynamicResolver = .init(context: self.context,
                        namespace: qualifier,
                        group: group)

                    resolver.link(article: article)

                    self.diagnoses += resolver.diagnoses
                }
            }
            if  let article:SymbolGraph.Article<Never> = culture.article
            {
                var resolver:DynamicResolver = .init(context: self.context,
                    namespace: qualifier,
                    group: group)

                resolver.link(article: article)

                self.diagnoses += resolver.diagnoses
            }
        }

        return scalars
    }
}
