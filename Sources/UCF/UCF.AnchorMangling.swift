extension UCF
{
    /// All Unicode characters except `#` are legal in anchor identifiers. But anchors that
    /// contain special characters are difficult to use in Markdown links. This type implements
    /// a many-to-one mangling scheme that gives each anchor a Markdown-friendly spelling.
    @frozen public
    struct AnchorMangling:RawRepresentable, Equatable, Hashable, Sendable
    {
        public
        let rawValue:String

        @inlinable public
        init(rawValue:String)
        {
            self.rawValue = rawValue
        }
    }
}
extension UCF.AnchorMangling:Comparable
{
    @inlinable public static
    func < (a:Self, b:Self) -> Bool { a.rawValue < b.rawValue }
}
extension UCF.AnchorMangling:CustomStringConvertible
{
    @inlinable public
    var description:String { self.rawValue }
}
extension UCF.AnchorMangling
{
    @inlinable public
    init(mangling string:String)
    {
        /// TODO: write more efficient implementation
        let components:[Substring] = string.split
        {
            if  $0.isLetter
            {
                return false
            }
            if  $0.isNumber
            {
                return false
            }
            switch $0
            {
            case ":":   return false
            case "'":   return false
            case "’":   return false
            case "‘":   return false
            default:    return true
            }
        }

        let joined:String = components.joined(separator: "-")
        self.init(rawValue: joined.lowercased())
    }
}
