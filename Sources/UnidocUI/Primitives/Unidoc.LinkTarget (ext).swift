import URI

extension Unidoc.LinkTarget
{
    mutating
    func export()
    {
        if  case .location(let uri) = self
        {
            self = .exported(uri)
        }
    }

    mutating
    func export(as article:Unidoc.ArticleVertex, in volume:Unidoc.Edition)
    {
        guard volume == article.id.edition
        else
        {
            self.export()
            return
        }

        //  This is a link to an article in the same volume. Most likely, the API
        //  user wants to also host the other article under the same domain. Because
        //  we know article paths are at most one component deep, we can just return
        //  the last component of the other article’s path as a relative URI.
        self = .relative(sibling: article)
    }

    /// Returns a relative link to a sibling article.
    static
    func relative(sibling article:Unidoc.ArticleVertex) -> Self
    {
        .location("../\(URI.Path.Component.push(article.stem.last.lowercased()))")
    }
}
