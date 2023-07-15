@frozen public
enum MarkdownSyntaxHighlight:String, Equatable, Hashable, Sendable
{
    case comment        = "syntax-comment"
    case binding        = "syntax-binding"
    case identifier     = "syntax-identifier"
    case keyword        = "syntax-keyword"
    case literal        = "syntax-literal"
    case magic          = "syntax-magic"
    case actor          = "syntax-actor"
    case `class`        = "syntax-class"
    case type           = "syntax-type"
    case `typealias`    = "syntax-typealias"
}
extension MarkdownSyntaxHighlight:CustomStringConvertible
{
    @inlinable public
    var description:String { self.rawValue }
}
