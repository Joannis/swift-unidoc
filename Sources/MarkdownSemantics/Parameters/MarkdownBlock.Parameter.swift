import MarkdownABI
import MarkdownAST

extension MarkdownBlock
{
    public final
    class Parameter:Container<MarkdownBlock>
    {
        public
        let name:String

        @inlinable public
        init(elements:[MarkdownBlock], name:String)
        {
            self.name = name
            super.init(elements)
        }
        public override
        func emit(into binary:inout Markdown.BinaryEncoder)
        {
            binary[.dt] { $0[.id] = "sp:\(self.name)" } = self.name
            binary[.dd]
            {
                super.emit(into: &$0)
            }
        }
    }
}
extension MarkdownBlock.Parameter
{
}
