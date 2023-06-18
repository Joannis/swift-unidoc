import MarkdownTrees

@frozen public
struct MarkdownDocumentationSupplement
{
    public
    let binding:MarkdownInline.Autolink?
    public
    var article:MarkdownDocumentation

    public
    init(binding:MarkdownInline.Autolink?, article:MarkdownDocumentation)
    {
        self.binding = binding
        self.article = article
    }
}
extension MarkdownDocumentationSupplement:MarkdownModel
{
    public
    func visit(_ yield:(MarkdownBlock) throws -> ()) rethrows
    {
        try self.article.visit(yield)
    }

    public
    init(attaching blocks:[MarkdownBlock])
    {
        if  case (let headline as MarkdownBlock.Heading)? = blocks.first,
            headline.level == 1,
            headline.elements.count == 1,
            case .autolink(let binding) = headline.elements[0]
        {
            self.init(binding: binding, article: .init(attaching: blocks.dropFirst()))
        }
        else
        {
            self.init(binding: nil, article: .init(attaching: blocks))
        }
    }
}
