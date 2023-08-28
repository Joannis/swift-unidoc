import FNV1
import MongoDB
import ModuleGraphs
import SemanticVersions
import SymbolGraphs
import Symbols
import Unidoc
import UnidocAnalysis
import UnidocLinker
import UnidocSelectors
import UnidocRecords

@frozen public
struct Database:Identifiable, Sendable
{
    public
    let id:Mongo.Database

    private
    init(id:Mongo.Database)
    {
        self.id = id
    }
}
extension Database
{
    var policies:Policies { .init() }

    var packages:Packages { .init(database: self.id) }

    @inlinable public
    var package:Package { .init(database: self.id) }
    @inlinable public
    var snapshots:Snapshots { .init(database: self.id) }

    var masters:Masters { .init(database: self.id) }
    var groups:Groups { .init(database: self.id) }
    var search:Search { .init(database: self.id) }
    var trees:Trees { .init(database: self.id) }
    var names:Names { .init(database: self.id) }
    var siteMaps:SiteMaps { .init(database: self.id) }

    public static
    var collation:Mongo.Collation
    {
        .init(locale: "en", // casing is a property of english, not unicode
            caseLevel: false, // url paths are case-insensitive
            normalization: true, // normalize unicode on insert
            strength: .secondary) // diacritics are significant
    }
}
extension Database
{
    public static
    func setup(_ id:Mongo.Database, in pool:__owned Mongo.SessionPool) async throws -> Self
    {
        let database:Self = .init(id: id)
        try await database.setup(with: try await .init(from: pool))
        return database
    }

    private
    func setup(with session:Mongo.Session) async throws
    {
        do
        {
            try await self.packages.setup(with: session)
            try await self.package.setup(with: session)
            try await self.snapshots.setup(with: session)

            try await self.masters.setup(with: session)
            try await self.groups.setup(with: session)
            try await self.search.setup(with: session)
            try await self.trees.setup(with: session)
            try await self.names.setup(with: session)
            try await self.siteMaps.setup(with: session)
        }
        catch let error
        {
            print("""
                warning: some indexes are no longer valid. \
                the database likely needs to be rebuilt.
                """)
            print(error)
        }
    }
}
extension Database
{
    /// Drops and reinitializes the database. This destroys *all* its data!
    public
    func nuke(with session:Mongo.Session) async throws
    {
        try await session.run(command: Mongo.DropDatabase.init(), against: self.id)
        try await self.setup(with: session)
    }
}
extension Database
{
    public
    func rebuild(with session:__shared Mongo.Session) async throws -> Int
    {
        //  TODO: we need to implement some kind of locking mechanism to prevent
        //  race conditions between rebuilds and pushes. This cannot be done with
        //  MongoDB transactions because deleting a very large number of records
        //  overflows the transaction cache.
        let zones:[Unidoc.Zone] = try await self.snapshots.list(with: session)

        try await self.masters.replace(with: session)
        try await self.groups.replace(with: session)
        try await self.search.replace(with: session)
        try await self.trees.replace(with: session)
        try await self.names.replace(with: session)
        try await self.siteMaps.replace(with: session)

        for zone:Unidoc.Zone in zones
        {
            let snapshot:Snapshot = try await self.snapshots.load(zone, with: session)
            let volume:Volume = try await self.pull(from: snapshot, with: session)

            try await self.push(volume, with: session)

            print("regenerated records for snapshot: \(snapshot.id)")
        }

        return zones.count
    }

    public
    func publish(docs:__owned Documentation,
        with session:__shared Mongo.Session) async throws -> SnapshotReceipt
    {
        let receipt:SnapshotReceipt = try await self.store(docs: docs, with: session)
        let volume:Volume = try await self.pull(from: .init(
                package: receipt.package,
                version: receipt.version,
                metadata: docs.metadata,
                graph: docs.graph),
            with: session)

        if  receipt.overwritten
        {
            try await self.search.delete(volume.id, with: session)

            try await self.masters.clear(receipt.zone, with: session)
            try await self.groups.clear(receipt.zone, with: session)
            try await self.trees.clear(receipt.zone, with: session)

            try await self.names.delete(receipt.zone, with: session)
        }

        try await self.push(volume, with: session)
        return receipt
    }

    public
    func siteMap(package:__owned PackageIdentifier,
        with session:__shared Mongo.Session) async throws -> Volume.SiteMap<PackageIdentifier>?
    {
        try await self.siteMaps.find(by: package, with: session)
    }
}
extension Database
{
    public
    func store(docs:Documentation, with session:Mongo.Session) async throws -> SnapshotReceipt
    {
        //  TODO: enforce population limits
        let registration:Package.Registration = try await self.package.register(
            docs.metadata.package,
            with: session)

        if  registration.new
        {
            let index:SearchIndex<Never?> = try await self.package.scan(
                with: session)

            try await self.packages.upsert(index, with: session)
        }

        return try await self.snapshots.push(docs, for: registration.cell, with: session)
    }
    private
    func pull(from snapshot:__owned Snapshot,
        with session:__shared Mongo.Session) async throws -> Volume
    {
        let context:DynamicContext = .init(snapshot,
            dependencies: try await self.snapshots.load(snapshot.metadata.pins(),
                with: session))

        let symbolicator:DynamicSymbolicator = .init(context: context,
            root: snapshot.metadata.root)
        let linker:DynamicLinker = .init(context: context)

        symbolicator.emit(linker.errors, colors: .enabled)

        let latest:Names.PatchView? = try await self.names.latest(of: snapshot.cell,
            with: session)

        var volume:Volume = .init(latest: latest?.id,
            masters: linker.masters,
            groups: linker.groups,
            names: linker.names)

        guard let patch:PatchVersion = volume.names.patch
        else
        {
            volume.names.latest = false
            return volume
        }

        if  let latest:PatchVersion = latest?.patch,
                latest > patch
        {
            volume.names.latest = false
        }
        else
        {
            volume.names.latest = true
            volume.latest = volume.names.id
        }

        return volume
    }
    private
    func push(_ volume:__owned Volume,
        with session:__shared Mongo.Session) async throws
    {
        let (index, trees):(SearchIndex<VolumeIdentifier>, [Volume.NounTree]) = volume.indexes()

        try await self.masters.insert(volume.masters, with: session)
        try await self.names.insert(volume.names, with: session)
        try await self.trees.insert(trees, with: session)
        try await self.search.insert(index, with: session)

        if  volume.names.latest
        {
            try await self.siteMaps.upsert(volume.siteMap(), with: session)
            try await self.groups.insert(volume.groups(latest: true), with: session)
        }
        else
        {
            try await self.groups.insert(volume.groups, with: session)
        }
        if  let latest:Unidoc.Zone = volume.latest
        {
            try await self.groups.align(latest: latest, with: session)
            try await self.names.align(latest: latest, with: session)
        }
    }
}
extension Database
{
    //  This should be part of the swift-mongodb package.
    private
    func explain<Command>(command:__owned Command,
        with session:Mongo.Session) async throws -> String
        where Command:MongoCommand
    {
        try await session.run(
            command: Mongo.Explain<Command>.init(
                verbosity: .executionStats,
                command: command),
            against: self.id)
    }

    public
    func explain<Query>(query:__owned Query,
        with session:Mongo.Session) async throws -> String
        where Query:DatabaseQuery
    {
        try await self.explain(command: query.command, with: session)
    }

    @inlinable public
    func execute<Query>(query:__owned Query,
        with session:Mongo.Session) async throws -> Query.Output?
        where Query:DatabaseQuery
    {
        try await session.run(command: query.command, against: self.id)
    }
}
