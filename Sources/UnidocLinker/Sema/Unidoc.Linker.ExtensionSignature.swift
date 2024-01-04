import Signatures
import Unidoc

extension Unidoc.Linker
{
    struct ExtensionSignature:Equatable, Hashable, Sendable
    {
        let conditions:ExtensionConditions
        let extendee:Unidoc.Scalar

        private
        init(conditions:ExtensionConditions, extendee:Unidoc.Scalar)
        {
            self.conditions = conditions
            self.extendee = extendee
        }
    }
}
extension Unidoc.Linker.ExtensionSignature
{
    static
    func extends(_ extendee:consuming Unidoc.Scalar,
        where conditions:consuming Unidoc.Linker.ExtensionConditions) -> Self
    {
        .init(conditions: conditions, extendee: extendee)
    }

    var culture:Int { self.conditions.culture }
}
