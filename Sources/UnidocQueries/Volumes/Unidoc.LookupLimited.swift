import MongoQL
import Unidoc
import UnidocRecords

extension Unidoc
{
    /// A context mode that looks up volumes for the current volume’s dependencies only.
    @frozen public
    enum LookupLimited:Sendable
    {
        case limited
    }
}
extension Unidoc.LookupLimited:Unidoc.LookupContext
{
    /// Sets the `output` to an empty array.
    public
    func groups(_ pipeline:inout Mongo.PipelineEncoder,
        volume _:Mongo.AnyKeyPath,
        vertex _:Mongo.AnyKeyPath,
        output:Mongo.AnyKeyPath)
    {
        pipeline[stage: .set] = .init
        {
            $0[output] = [] as [Never]
        }
    }

    /// Stores the editions of the current volume’s dependencies in `output.volumes`, and
    /// sets `output.scalars` to an empty array.
    public
    func edges(_ pipeline:inout Mongo.PipelineEncoder,
        volume:Mongo.AnyKeyPath,
        vertex _:Mongo.AnyKeyPath,
        groups _:Mongo.AnyKeyPath,
        output:(scalars:Mongo.AnyKeyPath, volumes:Mongo.AnyKeyPath))
    {
        pipeline[stage: .set] = .init
        {
            let dependencies:
                Mongo.List<Unidoc.VolumeMetadata.Dependency, Mongo.AnyKeyPath> = .init(
                in: volume / Unidoc.VolumeMetadata[.dependencies])

            $0[output.volumes] = .expr
            {
                $0[.setUnion] = .init
                {
                    $0.expr { $0[.map] = dependencies.map { $0[.pinned] } }
                }
            }
            $0[output.scalars] = [] as [Never]
        }
    }
}
