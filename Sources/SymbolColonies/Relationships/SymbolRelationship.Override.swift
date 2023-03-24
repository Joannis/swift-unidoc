extension SymbolRelationship
{
    @frozen public
    struct Override:Equatable, Hashable, Sendable
    {
        public
        let source:ScalarSymbolResolution
        public
        let target:ScalarSymbolResolution

        @inlinable public
        init(_ source:ScalarSymbolResolution,
            of target:ScalarSymbolResolution)
        {
            self.source = source
            self.target = target
        }
    }
}
extension SymbolRelationship.Override:CustomStringConvertible
{
    public
    var description:String
    {
        """
        (override: \(self.source), of: \(self.target))
        """
    }
}
