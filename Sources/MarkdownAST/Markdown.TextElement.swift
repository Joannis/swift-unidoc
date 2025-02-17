import MarkdownABI

extension Markdown
{
    public
    typealias TextElement = _MarkdownTextElement
}
/// The name of this protocol is ``Markdown.TextElement``.
public
protocol _MarkdownTextElement:Markdown.TreeElement
{
    /// Writes the plain text content of this element to the input string.
    static
    func += (text:inout String, self:Self)

    /// Returns the plain text content of this element.
    var text:String { get }

    /// Replaces symbolic codelinks in this element’s inline content
    /// with references.
    mutating
    func outline(by register:(Markdown.AnyReference) throws -> Int?) rethrows
}
extension Markdown.TextElement
{
    @inlinable public
    var text:String
    {
        var text:String = ""
        text += self
        return text
    }

    /// Does nothing.
    @inlinable public mutating
    func outline(by _:(Markdown.AnyReference) throws -> Int?)
    {
    }
}
