import MongoDB
import Unidoc
import UnidocRecords

extension Database
{
    /// A single-document collection containing a ``SearchIndex``.
    @frozen public
    struct Packages
    {
        public
        let database:Mongo.Database

        @inlinable public
        init(database:Mongo.Database)
        {
            self.database = database
        }
    }
}
extension Database.Packages:DatabaseCollection
{
    @inlinable public static
    var name:Mongo.Collection { "packages" }

    typealias ElementID = Never?

    static
    var indexes:[Mongo.CreateIndexStatement] { [] }
}
