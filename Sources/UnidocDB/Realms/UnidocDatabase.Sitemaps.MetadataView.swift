import BSONDecoding
import ModuleGraphs
import SymbolGraphs
import UnidocRecords

extension UnidocDatabase.Sitemaps
{
    /// A projected subset of the fields in ``Realm.Sitemap``, suitable for constructing a
    /// sitemap index file.
    @frozen public
    struct MetadataView
    {
        public
        let id:PackageIdentifier
        public
        let modified:BSON.Millisecond?

        @inlinable internal
        init(id:PackageIdentifier, modified:BSON.Millisecond?)
        {
            self.id = id
            self.modified = modified
        }
    }
}
extension UnidocDatabase.Sitemaps.MetadataView:BSONDocumentDecodable
{
    public
    typealias CodingKey = Realm.Sitemap.CodingKey

    @inlinable public
    init(bson:BSON.DocumentDecoder<CodingKey, some RandomAccessCollection<UInt8>>) throws
    {
        self.init(id: try bson[.id].decode(), modified: try bson[.modified]?.decode())
    }
}
