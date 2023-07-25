import MarkdownABI
import MarkdownRendering
import HTML
import Unidoc
import UnidocRecords

extension Inliner
{
    struct Passage
    {
        private
        let passage:Record.Passage
        private
        let inliner:Inliner

        init(_ inliner:Inliner, passage:Record.Passage)
        {
            self.inliner = inliner
            self.passage = passage
        }
    }
}
extension Inliner.Passage:HyperTextRenderableMarkdown
{
    var bytecode:MarkdownBytecode { self.passage.markdown }

    func load(_ reference:Int, into html:inout HTML.ContentEncoder)
    {
        guard self.passage.outlines.indices.contains(reference)
        else
        {
            return
        }

        switch self.passage.outlines[reference]
        {
        case .text(let text):
            html[.code] = text

        case .path(let stem, let scalars):
            //  Take the suffix of the stem, because it may include a module namespace,
            //  and we never render the module namespace, even if it was written in the
            //  codelink text.
            html[.code] = self.inliner.link(stem.split(separator: " ").suffix(scalars.count),
                to: scalars)
        }
    }
}
