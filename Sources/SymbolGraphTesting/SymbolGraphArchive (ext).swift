import BSON
import ModuleGraphs
import SemanticVersions
import SymbolGraphs
import System
import Testing

extension SymbolGraphArchive
{
    public static
    func load(package:PackageIdentifier,
        at version:AnyVersion? = nil,
        in directory:FilePath) throws -> Self
    {
        let filename:String = version.map { "\(package)@\($0).bson" } ?? "\(package).bson"
        return try .init(buffer: try (directory / filename).read())
    }

    @discardableResult
    public
    func save(as filename:String? = nil, in directory:FilePath) throws -> FilePath
    {
        let bson:BSON.Document = .init(encoding: self)

        let file:FilePath = directory / (filename ?? self.metadata.filename)
        try file.overwrite(with: bson.bytes)

        return file
    }
}
extension SymbolGraphArchive
{
    public
    func roundtrip(for tests:TestGroup, in directory:FilePath)
    {
        tests.do
        {
            let file:FilePath = try self.save(in: directory)

            if  let tests:TestGroup = tests / "roundtripping",
                let decoded:SymbolGraphArchive = tests.do(
                {
                    try .init(buffer: try file.read())
                })
            {
                tests.expect(decoded.metadata ==? self.metadata)
                //  We don’t want to dump the entire symbol graph to the terminal!
                tests.expect(true: decoded.graph == self.graph)
            }
        }
    }
}
