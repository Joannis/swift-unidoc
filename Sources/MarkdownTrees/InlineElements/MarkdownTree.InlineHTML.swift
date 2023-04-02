import MarkdownABI

extension MarkdownTree
{
    @frozen public
    struct InlineHTML
    {
        public
        var text:String

        @inlinable public
        init(text:String)
        {
            self.text = text
        }
    }
}
extension MarkdownTree.InlineHTML:MarkdownBinaryConvertibleElement
{
    /// Emits the raw text content of this element in a transparent instruction context.
    public
    func emit(into binary:inout MarkdownBinary)
    {
        binary[.transparent] { $0.write(text: self.text) }
    }
}
