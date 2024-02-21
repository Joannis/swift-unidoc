import BSON
import BSON_OrderedCollections
import OrderedCollections

extension Unidoc
{
    @frozen public
    struct Census:Equatable, Sendable
    {
        /// System programming interfaces.
        public
        var interfaces:OrderedDictionary<BSON.Key, Int>

        public
        var unweighted:Stats
        public
        var weighted:Stats

        @inlinable public
        init(interfaces:OrderedDictionary<BSON.Key, Int> = [:],
            unweighted:Stats = .init(),
            weighted:Stats = .init())
        {
            self.interfaces = interfaces
            self.unweighted = unweighted
            self.weighted = weighted
        }
    }
}
extension Unidoc.Census
{
    public
    enum CodingKey:String, Sendable
    {
        case interfaces = "I"

        case unweighted = "U"
        case weighted = "W"
    }
}
extension Unidoc.Census:BSONDocumentEncodable
{
    public
    func encode(to bson:inout BSON.DocumentEncoder<CodingKey>)
    {
        bson[.interfaces] = self.interfaces.isEmpty ? nil : self.interfaces
        bson[.unweighted] = self.unweighted
        bson[.weighted] = self.weighted
    }
}
extension Unidoc.Census:BSONDocumentDecodable
{
    @inlinable public
    init(bson:BSON.DocumentDecoder<CodingKey>) throws
    {
        self.init(
            interfaces: try bson[.interfaces]?.decode() ?? [:],
            unweighted: try bson[.unweighted].decode(),
            weighted: try bson[.weighted].decode())
    }
}
