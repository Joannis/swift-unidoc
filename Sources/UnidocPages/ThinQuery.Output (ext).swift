import HTTPServer
import UnidocQueries
import UnidocRecords
import URI

extension ThinQuery.Output:ServerResponseFactory
{
    public
    func response(for _:URI) throws -> ServerResponse
    {
        if  LookupPredicate.self is Volume.Range.Type
        {
            let inliner:Inliner = .init(principal: self.names)
                inliner.masters.add(self.masters)

            let feed:Site.Guides.Feed = .init(inliner, masters: self.masters)

            return .resource(feed.rendered())
        }
        else if let redirect:URI = self.redirect
        {
            return .redirect(.permanent("\(redirect)"))
        }
        else
        {
            return .resource(.init(.none,
                content: .string("Volume not found."),
                type: .text(.plain, charset: .utf8)))
        }
    }

    private
    var redirect:URI?
    {
        switch self.masters.first
        {
        case .article(let master)?: return Site.Docs[self.names, master.shoot]
        case .culture(let master)?: return Site.Docs[self.names, master.shoot]
        case .decl(let master)?:    return Site.Docs[self.names,
            self.masters.count > 1 ? .init(stem: master.stem) : master.shoot]
        case .file?, nil:           return nil
        case .meta?:                return Site.Docs[self.names]
        }
    }
}
