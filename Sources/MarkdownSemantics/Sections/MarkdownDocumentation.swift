import MarkdownABI
import MarkdownTrees

@frozen public
struct MarkdownDocumentation
{
    public
    var parameters:Parameters?
    public
    var returns:Returns?
    public
    var `throws`:Throws?
    public
    var article:[Block]

    public
    init(parameters:Parameters?, returns:Returns?, throws:Throws?, article:[Block])
    {
        self.parameters = parameters
        self.returns = returns
        self.throws = `throws`
        self.article = article
    }
}
extension MarkdownDocumentation
{
    public
    init(from tree:__shared MarkdownTree)
    {
        var parameters:(discussion:[MarkdownTree.Block], list:[Parameter]) = ([], [])
        var returns:[MarkdownTree.Block] = []
        var `throws`:[MarkdownTree.Block] = []
        var article:[Block] = []

        for block:MarkdownTree.Block in tree.blocks
        {
            switch block
            {
            case let list as MarkdownTree.UnorderedList:
                var items:[MarkdownTree.BlockItem] = []
                for item:MarkdownTree.BlockItem in list.elements
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
                        parameters.list.append(.init(identifier: parameter.identifier,
                            elements: item.elements))

                    case .keywords(.parameters):
                        for block:MarkdownTree.Block in item.elements
                        {
                            switch block
                            {
                            case let list as MarkdownTree.UnorderedList:
                                for item:MarkdownTree.BlockItem in list.elements
                                {
                                    let name:MarkdownParameterNamePrefix? = .extract(
                                        from: &item.elements)
                                    parameters.list.append(.init(
                                        identifier: name?.identifier ?? .underscore,
                                        elements: item.elements))
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
                        article.append(.semantic(aside, item.elements))
                    }
                }
                if !items.isEmpty
                {
                    list.elements = items
                    article.append(.regular(list))
                }
            
            case let quote as MarkdownTree.BlockQuote:
                guard let prefix:MarkdownBlockPrefix = .extract(from: &quote.elements)
                else
                {
                    article.append(.regular(quote))
                    continue
                }
                switch prefix
                {
                case .parameter(let parameter):
                    parameters.list.append(.init(identifier: parameter.identifier,
                        elements: quote.elements))

                case .keywords(.parameters):
                    parameters.discussion += quote.elements

                case .keywords(.returns):
                    returns += quote.elements
                
                case .keywords(.throws):
                    `throws` += quote.elements

                case .keywords(let keywords):
                    article.append(.semantic(keywords, quote.elements))
                }
            
            case let block:
                article.append(.regular(block))
            }
        }
    
        self.init(
            parameters: .init(discussion: parameters.discussion, list: parameters.list),
            returns: .init(returns),
            throws: .init(`throws`),
            article: article)
    }
}
extension MarkdownDocumentation
{
    public
    func emit(into binary:inout MarkdownBinary)
    {
        let discussion:ArraySlice<Block>

        if  case .regular(let paragraph as MarkdownTree.Paragraph)? = self.article.first
        {
            paragraph.emit(into: &binary)
            discussion = self.article.dropFirst()
        }
        else
        {
            discussion = self.article[...]
        }

        binary.write(reference: 0)

        self.parameters?.emit(into: &binary)
        self.returns?.emit(into: &binary)
        self.throws?.emit(into: &binary)

        for block:Block in discussion
        {
            block.emit(into: &binary)
        }
    }
}
