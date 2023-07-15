import BSONDecoding
import BSONEncoding
import ModuleGraphs
import SemanticVersions
import SymbolGraphs
import Unidoc
import UnidocRecords

extension DeepQuery.Output
{
    @frozen public
    struct Principal:Equatable, Sendable
    {
        public
        let extensions:[Record.Extension]
        public
        let matches:[Record.Master]
        public
        let master:Record.Master?
        public
        let zone:Record.Zone.Names

        @inlinable public
        init(
            extensions:[Record.Extension],
            matches:[Record.Master],
            master:Record.Master?,
            zone:Record.Zone.Names)
        {
            self.extensions = extensions
            self.matches = matches
            self.master = master
            self.zone = zone
        }
    }
}
extension DeepQuery.Output.Principal
{
    @frozen public
    enum CodingKey:String, CaseIterable
    {
        case extensions = "e"
        case matches = "a"
        case master = "m"

        //  These keys come from ``Record.Zone.CodingKey``.
        //  TODO: find a way to hitch this to the actual definitions
        //  in ``Record.Zone.CodingKey``.
        case package = "P"
        case version = "V"
        case refname = "G"
    }

    static
    subscript(key:CodingKey) -> BSON.Key { .init(key) }
}
extension DeepQuery.Output.Principal:BSONDocumentDecodable
{
    @inlinable public
    init(bson:BSON.DocumentDecoder<CodingKey, some RandomAccessCollection<UInt8>>) throws
    {
        self.init(
            extensions: try bson[.extensions].decode(),
            matches: try bson[.matches].decode(),
            master: try bson[.master]?.decode(),
            zone: .init(
                package: try bson[.package].decode(),
                version: try bson[.version].decode(),
                refname: try bson[.refname]?.decode()))
    }
}
