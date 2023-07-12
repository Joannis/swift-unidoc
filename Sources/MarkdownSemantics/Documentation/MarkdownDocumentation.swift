import MarkdownTrees

@frozen public
struct MarkdownDocumentation
{
    public
    var overview:MarkdownBlock.Paragraph?
    public
    var details:Details

    public
    init(overview:MarkdownBlock.Paragraph?, details:Details)
    {
        self.overview = overview
        self.details = details
    }
}
extension MarkdownDocumentation:MarkdownModel
{
    public
    func visit(_ yield:(MarkdownBlock) throws -> ()) rethrows
    {
        try self.overview.map(yield)
        try self.details.visit(yield)
    }

    public
    init(parser parse:() -> [MarkdownBlock])
    {
        self.init(attaching: parse())
    }
}
extension MarkdownDocumentation
{
    init(attaching blocks:some Sequence<MarkdownBlock>)
    {
        var parameters:(discussion:[MarkdownBlock], list:[MarkdownBlock.Parameter]) = ([], [])
        var returns:[MarkdownBlock] = []
        var `throws`:[MarkdownBlock] = []
        var article:[MarkdownBlock] = []

        for block:MarkdownBlock in blocks
        {
            switch block
            {
            case let list as MarkdownBlock.UnorderedList:
                var items:[MarkdownBlock.Item] = []
                for item:MarkdownBlock.Item in list.elements
                {
                    guard let prefix:MarkdownBlockPrefix = .extract(from: &item.elements)
                    else
                    {
                        items.append(item)
                        continue
                    }
                    switch prefix
                    {
                    case .parameter(let parameter):
                        parameters.list.append(.init(elements: item.elements,
                            name: parameter.name))

                    case .keywords(.parameters):
                        for block:MarkdownBlock in item.elements
                        {
                            switch block
                            {
                            case let list as MarkdownBlock.UnorderedList:
                                for item:MarkdownBlock.Item in list.elements
                                {
                                    let parameter:MarkdownParameterNamePrefix? = .extract(
                                        from: &item.elements)
                                    parameters.list.append(.init(elements: item.elements,
                                        name: parameter?.name ?? "_"))
                                }

                            case let block:
                                parameters.discussion.append(block)
                            }
                        }

                    case .keywords(.returns):
                        returns += item.elements

                    case .keywords(.throws):
                        `throws` += item.elements

                    case .keywords(let aside):
                        article.append(aside(item.elements))
                    }
                }
                if !items.isEmpty
                {
                    list.elements = items
                    article.append(list)
                }

            case let quote as MarkdownBlock.Quote:
                guard let prefix:MarkdownBlockPrefix = .extract(from: &quote.elements)
                else
                {
                    article.append(quote)
                    continue
                }
                switch prefix
                {
                case .parameter(let parameter):
                    parameters.list.append(.init(elements: quote.elements,
                        name: parameter.name))

                case .keywords(.parameters):
                    parameters.discussion += quote.elements

                case .keywords(.returns):
                    returns += quote.elements

                case .keywords(.throws):
                    `throws` += quote.elements

                case .keywords(let aside):
                    article.append(aside(quote.elements))
                }

            case let block:
                article.append(block)
            }
        }

        let overview:MarkdownBlock.Paragraph?
        switch article.first
        {
        case (let paragraph as MarkdownBlock.Paragraph)?:
            overview = paragraph
            article.removeFirst()

        default:
            overview = nil
        }

        self.init(overview: overview, details: .init(
            parameters: parameters.discussion.isEmpty && parameters.list.isEmpty ?
                nil : .init(parameters.discussion, list: parameters.list),
            returns: returns.isEmpty ? nil : .init(returns),
            throws: `throws`.isEmpty ? nil : .init(`throws`),
            article: article))
    }
}
