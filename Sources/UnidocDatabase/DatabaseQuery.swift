import BSONDecoding
import MongoDB

public
protocol DatabaseQuery<Output>:Sendable
{
    associatedtype Output:BSONDocumentDecodable

    func build(pipeline:inout Mongo.Pipeline)

    var origin:Mongo.Collection { get }
    var hint:Mongo.SortDocument? { get }
}
extension DatabaseQuery
{
    @inlinable public
    var command:Mongo.Aggregate<Mongo.Single<Output>>
    {
        .init(self.origin, pipeline: .init(with: self.build(pipeline:)))
        {
            $0[.collation] = UnidocDatabase.collation
            $0[.hint] = self.hint
        }
    }
}
