import MarkdownABI
import MarkdownAST

extension MarkdownBlock.Aside
{
    public final
    class Returns:MarkdownBlock.Aside
    {
        public class override
        var context:Markdown.Bytecode.Context { .returns }
    }
}
