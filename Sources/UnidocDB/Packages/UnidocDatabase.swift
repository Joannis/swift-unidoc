import FNV1
import GitHubAPI
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
struct UnidocDatabase:Identifiable, Sendable
{
    public
    let id:Mongo.Database

    @inlinable public
    init(id:Mongo.Database)
    {
        self.id = id
    }
}
extension UnidocDatabase
{
    var policies:Policies { .init() }

    @inlinable public
    var packages:Packages { .init(database: self.id) }
    @inlinable public
    var editions:Editions { .init(database: self.id) }
    @inlinable public
    var graphs:Graphs { .init(database: self.id) }

    var meta:Meta { .init(database: self.id) }

    @inlinable public
    var vertices:Vertices { .init(database: self.id) }
    var groups:Groups { .init(database: self.id) }
    var search:Search { .init(database: self.id) }
    var trees:Trees { .init(database: self.id) }
    @inlinable public
    var names:Names { .init(database: self.id) }
    var siteMaps:SiteMaps { .init(database: self.id) }
}
extension UnidocDatabase:DatabaseModel
{
    @inlinable public static
    var collation:Mongo.Collation
    {
        .init(locale: "en", // casing is a property of english, not unicode
            caseLevel: false, // url paths are case-insensitive
            normalization: true, // normalize unicode on insert
            strength: .secondary) // diacritics are significant
    }

    public
    func setup(with session:Mongo.Session) async throws
    {
        try await self.packages.setup(with: session)
        try await self.editions.setup(with: session)
        try await self.graphs.setup(with: session)
        try await self.meta.setup(with: session)

        try await self.vertices.setup(with: session)
        try await self.groups.setup(with: session)
        try await self.search.setup(with: session)
        try await self.trees.setup(with: session)
        try await self.names.setup(with: session)
        try await self.siteMaps.setup(with: session)
    }
}

@available(*, unavailable, message: "unused")
extension UnidocDatabase
{
    private
    func _clear(with session:Mongo.Session) async throws
    {
        try await self.vertices.replace(with: session)
        try await self.groups.replace(with: session)
        try await self.search.replace(with: session)
        try await self.trees.replace(with: session)
        try await self.names.replace(with: session)
        try await self.siteMaps.replace(with: session)
    }

    func _editions(of package:PackageIdentifier,
        with session:Mongo.Session) async throws -> [PackageEdition]
    {
        try await session.run(
            command: Mongo.Aggregate<Mongo.Cursor<PackageEdition>>.init(Packages.name,
                pipeline: .init
                {
                    $0.stage
                    {
                        $0[.match] = .init
                        {
                            $0[PackageRecord[.id]] = package
                        }
                    }

                    let editions:Mongo.KeyPath = "editions"

                    $0.stage
                    {
                        $0[.lookup] = .init
                        {
                            $0[.from] = Editions.name
                            $0[.localField] = PackageRecord[.cell]
                            $0[.foreignField] = PackageEdition[.package]
                            $0[.as] = editions
                        }
                    }

                    $0.stage
                    {
                        $0[.lookup] = .init
                        {
                            let cell:Mongo.Variable<Int32> = "cell"

                            $0[.from] = Graphs.name
                            $0[.let] = .init
                            {
                                $0[let: cell] = PackageRecord[.cell]
                            }
                            $0[.pipeline] = .init
                            {
                                $0.stage
                                {
                                    $0[.match] = .init
                                    {
                                        $0[.expr] = .expr
                                        {
                                            $0[.eq] = (Snapshot[.package], cell)
                                        }
                                    }
                                }

                                $0.stage
                                {
                                    $0[.sort] = .init
                                    {
                                        $0[Snapshot[.version]] = (-)
                                    }
                                }

                                $0.stage
                                {
                                    $0[.limit] = 1
                                }

                                $0.stage
                                {
                                    $0[.replaceWith] = Snapshot[.metadata]
                                }
                            }
                            $0[.as] = "recent"
                        }
                    }

                    $0.stage
                    {
                        $0[.unwind] = editions
                    }

                    $0.stage
                    {
                        $0[.replaceWith] = editions
                    }
                },
                stride: 1),
            against: self.id)
        {
            try await $0.reduce(into: [], += )
        }
    }
}

extension UnidocDatabase
{
    @_spi(testable)
    public
    func track(package:PackageIdentifier,
        with session:Mongo.Session) async throws -> Int32
    {
        try await self.packages.register(package,
            updating: self.meta,
            tracking: nil,
            with: session).coordinate
    }

    public
    func track(repo:GitHub.Repo, with session:Mongo.Session) async throws -> Int32
    {
        /// Currently, package identifiers are just the name of the repository.
        try await self.packages.register(.init(repo.name),
            updating: self.meta,
            tracking: .github(repo),
            with: session).coordinate
    }

    public
    func store(docs:SymbolGraphArchive,
        with session:Mongo.Session) async throws -> SnapshotReceipt
    {
        let placement:Packages.Placement = try await self.packages.register(
            docs.metadata.package,
            updating: self.meta,
            tracking: nil,
            with: session)

        let version:Int32

        if  let commit:SymbolGraphMetadata.Commit = docs.metadata.commit,
            let semver:SemanticVersion = .init(refname: commit.refname)
        {
            let placement:Editions.Placement = try await self.editions.register(
                package: placement.coordinate,
                version: semver,
                refname: commit.refname,
                sha1: commit.hash,
                with: session)

            version = placement.coordinate
        }
        else if case .swift = docs.metadata.package,
            let tagname:String = docs.metadata.commit?.refname
        {
            //  FIXME: we need a better way to handle this
            let semver:SemanticVersion
            switch tagname
            {
            case "swift-5.8.1-RELEASE": semver = .release(.v(5, 8, 1))
            case "swift-5.9-RELEASE":   semver = .release(.v(5, 9, 0))
            case _:
                fatalError("unimplemented")
            }

            let placement:Editions.Placement = try await self.editions.register(
                package: placement.coordinate,
                version: semver,
                refname: tagname,
                sha1: nil,
                with: session)

            version = placement.coordinate
        }
        else
        {
            version = -1
        }

        let snapshot:Snapshot = .init(
            package: placement.coordinate,
            version: version,
            metadata: docs.metadata,
            graph: docs.graph)

        let upsert:SnapshotReceipt.Upsert = try await self.graphs.upsert(snapshot,
            with: session)

        return .init(id: snapshot.id,
            edition: snapshot.edition,
            type: upsert,
            repo: placement.repo)
    }
}

extension UnidocDatabase
{
    public
    func publish(_ docs:__owned SymbolGraphArchive,
        with session:Mongo.Session) async throws -> SnapshotReceipt
    {
        let receipt:SnapshotReceipt = try await self.store(docs: docs, with: session)

        let volume:Volume = try await self.link(.init(
                package: receipt.package,
                version: receipt.version,
                metadata: docs.metadata,
                graph: docs.graph),
            with: session)

        _ = consume docs

        try await self.fill(volume: consume volume,
            clear: receipt.type == .update,
            with: session)

        return receipt
    }

    public
    func uplink(
        package:Int32,
        version:Int32?,
        with session:Mongo.Session) async throws -> Int
    {
        var uplinked:Int = 0

        try await self.graphs.list(
            filter: (package: package, version: version),
            with: session)
        {
            try await self.fill(
                volume: try await self.link($0, with: session),
                clear: true,
                with: session)

            uplinked += 1
        }

        return uplinked
    }
}
extension UnidocDatabase
{
    private
    func fill(volume:__owned Volume,
        clear:Bool = true,
        with session:Mongo.Session) async throws
    {
        if  clear
        {
            try await self.search.delete(volume.id, with: session)

            try await self.vertices.clear(volume.edition, with: session)
            try await self.groups.clear(volume.edition, with: session)
            try await self.trees.clear(volume.edition, with: session)

            try await self.names.delete(volume.edition, with: session)
        }

        let (index, trees):(SearchIndex<VolumeIdentifier>, [Volume.TypeTree]) = volume.indexes()

        try await self.vertices.insert(some: volume.vertices, with: session)
        try await self.names.insert(some: volume.names, with: session)
        try await self.trees.insert(some: trees, with: session)
        try await self.search.insert(some: index, with: session)

        if  volume.names.latest
        {
            try await self.siteMaps.upsert(some: volume.siteMap(), with: session)
            try await self.groups.insert(some: volume.groups(latest: true), with: session)
        }
        else
        {
            try await self.groups.insert(some: volume.groups, with: session)
        }
        if  let latest:Unidoc.Zone = volume.latest
        {
            try await self.groups.align(latest: latest, with: session)
            try await self.names.align(latest: latest, with: session)
        }
    }

    private
    func link(_ snapshot:__owned Snapshot,
        with session:Mongo.Session) async throws -> Volume
    {
        let context:DynamicContext = .init(snapshot,
            dependencies: try await self.graphs.load(snapshot.metadata.pins(),
                with: session))

        let symbolicator:DynamicSymbolicator = .init(context: context,
            root: snapshot.metadata.root)
        let linker:DynamicLinker = .init(context: context)

        symbolicator.emit(linker.errors, colors: .enabled)

        let latestRelease:Names.PatchView? = try await self.names.latestRelease(
            of: snapshot.package,
            with: session)

        let id:Snapshot.ID = snapshot.id

        var volume:Volume = .init(latest: latestRelease?.id,
            vertices: linker.vertices,
            groups: linker.groups,
            names: .init(id: snapshot.edition,
                display: snapshot.metadata.display,
                refname: snapshot.metadata.commit?.refname,
                volume: id.volume,
                latest: true,
                patch: id.version.stable?.patch))

        guard case .stable(.release(let patch, build: _)) = id.version.canonical
        else
        {
            volume.names.latest = false
            volume.names.patch = nil
            return volume
        }

        if  let latest:PatchVersion = latestRelease?.patch,
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
}
extension UnidocDatabase
{
    public
    func siteMap(package:consuming PackageIdentifier,
        with session:Mongo.Session) async throws -> Volume.SiteMap<PackageIdentifier>?
    {
        try await self.siteMaps.find(by: package, with: session)
    }
}
