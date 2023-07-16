import MongoDB
import MongoTesting
import SymbolGraphBuilder
import SymbolGraphs
import UnidocDatabase

struct DatabaseQueries:MongoTestBattery
{
    func run(_ tests:TestGroup, pool:Mongo.SessionPool, database:Mongo.Database) async throws
    {
        let database:Database = try await .setup(database, in: pool)

        let workspace:Workspace = try await .create(at: ".testing")
        let toolchain:Toolchain = try await .detect()

        let example:Documentation = try await toolchain.generateDocs(
            for: try await .local(package: "swift-crosslinks",
                from: "TestPackages",
                in: workspace,
                clean: true),
            pretty: true)

        let swift:Documentation
        do
        {
            //  Use the cached binary if available.
            swift = try .load(package: .swift, at: toolchain.version, in: workspace.path)
        }
        catch
        {
            swift = try await toolchain.generateDocs(
            for: try await .swift(in: workspace, clean: true))
        }

        let session:Mongo.Session = try await .init(from: pool)

        tests.expect(try await database.publish(docs: swift, with: session) ==? .init(
            overwritten: false,
            package: 0,
            version: 0,
            id: "swift v5.8.1 x86_64-unknown-linux-gnu"))

        tests.expect(try await database.publish(docs: example, with: session) ==? .init(
            overwritten: false,
            package: 1,
            version: 0,
            id: "$anonymous"))


        // try await database._get(package: "swift-crosslinks",
        //     version: nil,
        //     stem: "BarbieCore Barbie Dreamhouse Keys",
        //     hash: nil,
        //     with: session)

        // try await database._get(package: "swift-crosslinks",
        //     version: nil,
        //     stem: "barbiecore barbie dreamhouse keys",
        //     hash: nil,
        //     with: session)

        if  let tests:TestGroup = tests / "Dictionary" / "Keys",
            let query:DeepQuery = tests.expect(
                value: .init(.docs, "swift:swift", ["dictionary", "keys"]))
        {
            await tests.do
            {
                let output:[DeepQuery.Output] = try await database.execute(query: query,
                    with: session)

                tests.expect(output.count ==? 1)
            }
        }

        //  Test an ambiguous query.
        if  let tests:TestGroup = tests / "Int" / "init",
            let query:DeepQuery = tests.expect(
                value: .init(.docs, "swift:swift", ["int.init(_:)"]))
        {
            await tests.do
            {
                let output:[DeepQuery.Output] = try await database.execute(query: query,
                    with: session)

                tests.expect(output.count ==? 1)
            }
        }

        // try await database._get(package: "swift-crosslinks",
        //     version: nil,
        //     stem: "barbiecore barbie dreamhouse\tkeys",
        //     hash: nil,
        //     with: session)
    }
}
