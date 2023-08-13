import FNV1
import Unidoc
import UnidocRecords

@frozen public
struct Records
{
    public
    var latest:Unidoc.Zone?

    public
    var masters:[Record.Master]
    public
    var groups:[Record.Group]
    public
    var zone:Record.Zone

    @inlinable public
    init(latest:Unidoc.Zone?,
        masters:[Record.Master],
        groups:[Record.Group],
        zone:Record.Zone)
    {
        self.latest = latest

        self.masters = masters
        self.groups = groups
        self.zone = zone
    }
}
extension Records
{
    public
    func _buildTypeTrees() -> [TypeTree]
    {
        var levels:[Unidoc.Scalar: Records.TypeLevels] = [:]
        for master:Record.Master in self.masters
        {
            let culture:Unidoc.Scalar
            let scope:Unidoc.Scalar?
            let node:TypeLevels.Node
            switch master
            {
            case .article(let master):
                culture = master.culture
                scope = nil
                node = .init(stem: master.stem)

            case .decl(let master):
                switch master.phylum
                {
                case .actor, .class, .struct, .enum, .protocol: break
                case _:                                         continue
                }

                let hash:FNV24? = master.route == .hashed ? master.hash : nil
                culture = master.culture
                scope = master.scope.last
                node = .init(stem: master.stem, hash: hash)

            case .file, .culture:
                continue
            }

            levels[culture, default: .init()][node.stem.depth, master.id] = (scope, node)
        }

        //  TODO: include extended types

        var trees:[TypeTree] = []
            trees.reserveCapacity(levels.count)

        var l:Dictionary<Unidoc.Scalar, Records.TypeLevels>.Index = levels.startIndex
        while   l < levels.endIndex
        {
            defer
            {
                l = levels.index(after: l)
            }

            levels.values[l].collapse()

            let (culture, levels):(Unidoc.Scalar, Records.TypeLevels) = levels[l]

            trees.append(.init(id: culture,
                top: levels.top.values.sorted { $0.stem < $1.stem }))
        }

        return trees
    }
}
