import Unidoc
import UnidocRecords

extension InlinerCache
{
    struct Zones:Sendable
    {
        let principal:(id:Unidoc.Zone, trunk:Record.Trunk)
        private(set)
        var secondary:[Unidoc.Zone: Record.Trunk]

        init(
            principal:(id:Unidoc.Zone, trunk:Record.Trunk),
            secondary:[Unidoc.Zone: Record.Trunk] = [:])
        {
            self.principal = principal
            self.secondary = secondary
        }
    }
}
extension InlinerCache.Zones
{
    mutating
    func add(_ zones:[Record.Zone])
    {
        for zone:Record.Zone in zones where
            zone.id != self.principal.id
        {
            self.secondary[zone.id] = zone.names
        }
    }
}
extension InlinerCache.Zones
{
    subscript(_ zone:Unidoc.Zone) -> Record.Trunk?
    {
        self.principal.id == zone ? self.principal.trunk : self.secondary[zone]
    }
}
