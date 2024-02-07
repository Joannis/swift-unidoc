import BSON
import MongoQL
import Signatures
import Unidoc
import UnidocRecords

extension Unidoc.GroupLayer
{
    func adjacent(to group:Mongo.Variable<Unidoc.AnyGroup>) -> Mongo.Expression
    {
        .expr
        {
            $0[.concatArrays] = .init
            {
                switch self
                {
                case .protocols:
                    let conditional:Mongo.List<Unidoc.ConformingType, Mongo.AnyKeyPath> = .init(
                        in: group[.conditional])

                    $0.append([group[.culture]])
                    $0.expr
                    {
                        $0[.coalesce] = (group[.unconditional], [] as [Never])
                    }
                    $0.expr
                    {
                        $0[.map] = conditional.map { $0[.id] }
                    }
                    $0.expr
                    {
                        $0[.reduce] = conditional.flatMap
                        {
                            (type:Mongo.Variable<Unidoc.ConformingType>) -> Mongo.Expression in
                            .expr
                            {
                                $0[.map] = type.constraints.map { $0[.nominal] }
                            }
                        }
                    }
                }
            }
        }
    }
}
