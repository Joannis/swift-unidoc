import MongoQL
import SemanticVersions
import SymbolGraphs
import Symbols
import Unidoc
import UnidocRecords

extension Unidex
{
    struct PinDependenciesQuery:Sendable
    {
        private
        let patches:[Symbol.PackageDependency<PatchVersion>]

        private
        init(patches:[Symbol.PackageDependency<PatchVersion>])
        {
            self.patches = patches
        }
    }
}
extension Unidex.PinDependenciesQuery
{
    init?(for snapshot:borrowing Unidex.Snapshot)
    {
        var patches:[Symbol.PackageDependency<PatchVersion>] = []

        for case (nil, let dependency) in zip(snapshot.pins, snapshot.metadata.dependencies)
        {
            guard
            let version:PatchVersion = dependency.version.release
            else
            {
                return nil
            }

            patches.append(.init(package: dependency.package, version: version))
        }

        if  patches.isEmpty
        {
            return nil
        }

        self.init(patches: patches)
    }
}
extension Unidex.PinDependenciesQuery:Mongo.PipelineQuery
{
    typealias CollectionOrigin = UnidocDatabase.PackageAliases
    typealias Collation = SimpleCollation
    typealias Iteration = Mongo.SingleBatch<Symbol.PackageDependency<Unidoc.Edition>>

    var hint:Mongo.CollectionIndex? { nil }

    func build(pipeline:inout Mongo.PipelineEncoder)
    {
        //  Lookup the package alias documents by symbol.
        pipeline[.match] = .init
        {
            $0[Unidex.PackageAlias[.id]] = .init { $0[.in] = self.patches.lazy.map(\.package) }
        }

        let coordinate:Mongo.KeyPath = "_coordinate"
        let patch:Mongo.KeyPath = "_patch"

        //  We are only interested in the coordinate value stored in the alias documents.
        pipeline[.replaceWith] = .init
        {
            $0[Symbol.PackageDependency<Unidoc.Edition>[.package]] = Unidex.PackageAlias[.id]
            $0[coordinate] = Unidex.PackageAlias[.coordinate]
        }

        //  Map the coordinates back to the patch versions associated with the original
        //  packages.
        pipeline[.lookup] = .init
        {
            $0[.foreignField] = Symbol.PackageDependency<PatchVersion>[.package]
            $0[.localField] = Symbol.PackageDependency<Unidoc.Edition>[.package]
            $0[.pipeline] = .init { $0[.documents] = self.patches }
            $0[.as] = patch
        }

        pipeline[.unwind] = patch

        pipeline[.set] = .init
        {
            $0[patch] = patch / Symbol.PackageDependency<PatchVersion>[.version]
        }

        let edition:Mongo.KeyPath = "_edition"

        //  Lookup release editions using the package coordinate and patch version.
        pipeline[.lookup] = .init
        {
            let p:Mongo.Variable<Int32> = "p"
            let v:Mongo.Variable<PatchVersion> = "v"

            $0[.from] = UnidocDatabase.Editions.name
            $0[.let] = .init
            {
                $0[let: p] = coordinate
                $0[let: v] = patch
            }
            $0[.pipeline] = .init
            {
                $0[.match] = .init
                {
                    $0[.and] = .init
                    {
                        $0.append
                        {
                            $0[.expr] = .expr
                            {
                                $0[.eq] = (Unidoc.EditionMetadata[.package], p)
                            }
                        }

                        $0.append
                        {
                            $0[.expr] = .expr
                            {
                                $0[.eq] = (Unidoc.EditionMetadata[.patch], v)
                            }
                        }

                        $0.append
                        {
                            $0[Unidoc.EditionMetadata[.release]] = true
                        }
                    }
                }
            }
            $0[.as] = edition
        }

        pipeline[.unwind] = edition

        pipeline[.set] = .init
        {
            $0[Symbol.PackageDependency<Unidoc.Edition>[.version]] =
                edition / Unidoc.EditionMetadata[.id]
        }

        //  Lint temporary variables.
        pipeline[.unset] = [coordinate, patch, edition]
    }
}
