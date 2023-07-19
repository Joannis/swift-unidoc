import LexicalPaths
import SymbolGraphs
import Unidoc
import UnidocRecords

extension DynamicLinker
{
    struct Extensions
    {
        private
        var table:[ExtensionSignature: Extension]
        /// A copy of the current snapshot’s zone. This helps us avoid overlapping
        /// access when performing mutations on `self` while reading from the original
        /// snapshot context.
        private
        let zone:Unidoc.Zone

        init(table:[ExtensionSignature: Extension] = [:], zone:Unidoc.Zone)
        {
            self.table = table
            self.zone = zone
        }
    }
}
extension DynamicLinker.Extensions
{
    var count:Int
    {
        self.table.count
    }

    func records(context:DynamicContext) -> [Record.Extension]
    {
        self.table.sorted { $0.value.id < $1.value.id }
            .map
        {
            .init(signature: $0.key, extension: $0.value, context: context)
        }
    }
}
extension DynamicLinker.Extensions
{
    subscript(signature:DynamicLinker.ExtensionSignature) -> DynamicLinker.Extension
    {
        _read
        {
            let next:Unidoc.Scalar = self.zone + self.count * .extension
            yield  self.table[signature, default: .init(id: next)]
        }
        _modify
        {
            let next:Unidoc.Scalar = self.zone + self.count * .extension
            yield &self.table[signature, default: .init(id: next)]
        }
    }
}
extension DynamicLinker.Extensions
{
    mutating
    func add(_ extensions:[SymbolGraph.Extension],
        indexingConformances:Bool,
        extending scope:Int32,
        context:DynamicContext,
        groups:[DynamicResolutionGroup],
        errors:inout [any DynamicLinkerError]) -> DynamicLinker.Conformances
    {
        guard   let scope:Unidoc.Scalar = context.current.decls[scope],
                let path:UnqualifiedPath = context[scope.package]?.nodes[scope]?.decl?.path
        else
        {
            errors.append(DroppedExtensionsError.init(
                extendee: context.current.graph.decls[scope],
                count: extensions.count))
            return [:]
        }

        var conformances:DynamicLinker.Conformances = [:]
        for `extension`:SymbolGraph.Extension in extensions
        {
            let signature:DynamicLinker.ExtensionSignature = .init(
                conditions: `extension`.conditions.map
                {
                    $0.map { context.current.decls[$0] }
                },
                culture: context.current.zone + `extension`.culture * .module,
                extends: scope)

            let group:DynamicResolutionGroup = groups[`extension`.culture]

            let optimizer:Optimizer.Extension = group.optimizer.extensions[signature.globalized]
            let protocols:[Unidoc.Scalar] = `extension`.conformances.compactMap
            {
                context.current.decls[$0]
            }
            //  It’s possible for two locally-disjoint extensions to coalesce
            //  into a single global extension due to constraint dropping...
            {
                $0.conformances += protocols.filter { !optimizer.conformances.contains($0) }
                $0.features += `extension`.features.compactMap
                {
                    if  let scalar:Unidoc.Scalar = context.current.decls[$0],
                        !optimizer.features.contains(scalar)
                    {
                        return scalar
                    }
                    else
                    {
                        return nil
                    }
                }
                $0.nested += `extension`.nested.compactMap
                {
                    if  let scalar:Unidoc.Scalar = context.current.decls[$0]
                    {
                        if  optimizer.nested.contains(scalar)
                        {
                            print("\(scalar) is already nested in \(signature). this is impossible!")
                            fatalError()
                        }
                        return scalar
                    }
                    else
                    {
                        return nil
                    }
                }

                guard   let article:SymbolGraph.Article<Never> = `extension`.article
                else
                {
                    return
                }
                guard case (nil, nil) = ($0.overview, $0.details)
                else
                {
                    errors.append(DroppedPassagesError.fromExtension($0.id, of: scope))
                    return
                }

                var resolver:DynamicResolver = .init(context: context,
                    namespace: context.current.graph.namespaces[`extension`.namespace],
                    group: groups[`extension`.culture],
                    scope: [String].init(path))

                ($0.overview, $0.details) = resolver.link(article: article)

                errors += resolver.errors

            } (&self[signature])

            if  indexingConformances
            {
                for `protocol`:Unidoc.Scalar in protocols
                {
                    conformances[to: `protocol`].append(signature)
                }
            }
        }
        return conformances
    }
}
