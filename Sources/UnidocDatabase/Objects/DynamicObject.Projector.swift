import SymbolGraphs
import Symbols

extension DynamicObject
{
    struct Projector
    {
        let translator:Translator

        private
        let addresses:SymbolGraph.Table<GlobalAddress?>

        private
        init(translator:Translator, addresses:SymbolGraph.Table<GlobalAddress?>)
        {
            self.translator = translator
            self.addresses = addresses
        }
    }
}
extension DynamicObject.Projector
{
    init(translator:DynamicObject.Translator,
        upstream:__owned [ScalarSymbol: GlobalAddress],
        docs:__shared Documentation)
    {
        self.init(translator: translator,
            addresses: docs.graph.link
            {
                translator[scalar: $0]
            }
            dynamic:
            {
                upstream[$0]
            })
    }
    init(policies:__shared DocumentationDatabase.Policies,
        upstream:__owned [ScalarSymbol: GlobalAddress],
        receipt:__shared DocumentationDatabase.ObjectReceipt,
        docs:__shared Documentation) throws
    {
        self.init(translator: try .init(policies: policies,
                package: receipt.package,
                version: receipt.version,
                docs: docs),
            upstream: upstream,
            docs: docs)
    }
}
extension DynamicObject.Projector
{
    static
    func * (address:Int32, self:Self) -> GlobalAddress?
    {
        self.addresses[address] ?? nil
    }
    static
    func / (address:GlobalAddress, self:Self) -> Int32?
    {
        self.translator[address].scalar
    }
}
