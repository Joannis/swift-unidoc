import FNV1
import MD5
import Multiparts
import Symbols
import UnidocDatabase
import UnidocPages
import UnidocQueries
import UnidocSelectors
import UnidocRecords
import URI

enum AnyOperation:Sendable
{
    case datafile(Cache<Site.Asset>.Request)
    case dataless(any DatalessOperation)
    case database(any DatabaseOperation)
}
extension AnyOperation
{
    static
    func get(root:String, rest:ArraySlice<String>, uri:URI, tag:MD5?) -> Self?
    {
        if  let trunk:Int = rest.indices.first
        {
            return .get(root: root,
                trunk: rest[trunk],
                stem: rest[rest.index(after: trunk)...],
                uri: uri,
                tag: tag)
        }
        else
        {
            return .get(root: root, uri: uri, tag: tag)
        }
    }

    private static
    func get(root:String, uri:URI, tag:MD5?) -> Self?
    {
        switch root
        {
        case Site.Admin.root:   return .database(AdminOperation.status)
        case _:                 return nil
        }
    }

    private static
    func get(root:String, trunk:String, stem:ArraySlice<String>, uri:URI, tag:MD5?) -> Self?
    {
        switch root
        {
        case Site.Admin.root:
            let action:Site.Action? = .init(rawValue: trunk)
            return action.map { .dataless(ConfirmOperation.init($0)) }

        case Site.Asset.root:
            let asset:Site.Asset? = .init(rawValue: trunk)
            return asset.map { .datafile(.init($0, tag: tag)) }

        case "sitemap":
            return .database(SiteMapOperation.init(package: .init(trunk), uri: uri, tag: tag))

        case "reference":
            return .get(legacy: trunk, stem: stem, uri: uri)

        case "learn":
            return .get(legacy: trunk, stem: stem, uri: uri)

        case _:
            break
        }

        var explain:Bool = false
        var hash:FNV24? = nil

        for (key, value):(String, String) in uri.query?.parameters ?? []
        {
            switch key
            {
            case "explain": explain = value == "true"
            case "hash":    hash = .init(value)
            case _:         continue
            }
        }

        switch root
        {
        case Site.Docs.root:
            return .database(QueryOperation<WideQuery>.init(
                explain: explain,
                query: .init(
                    volume: .init(trunk),
                    lookup: .init(stem: stem, hash: hash)),
                uri: uri,
                tag: tag))

        case Site.Guides.root:
            return .database(QueryOperation<ThinQuery<Volume.Range>>.init(
                explain: explain,
                query: .init(
                    volume: .init(trunk),
                    lookup: .articles),
                uri: uri,
                tag: tag))

        case "lunr":
            if  let id:VolumeIdentifier = .init(trunk)
            {
                return .database(QueryOperation<SearchIndexQuery<VolumeIdentifier>>.init(
                    explain: explain,
                    query: .init(
                        from: Database.Search.name,
                        tag: tag,
                        id: id),
                    uri: uri,
                    tag: tag))
            }
            else if trunk == "packages.json"
            {
                return .database(QueryOperation<SearchIndexQuery<Never?>>.init(
                    explain: false,
                    query: .init(
                        from: Database.Packages.name,
                        tag: tag,
                        id: nil),
                    uri: uri))
            }
            else
            {
                return nil
            }

        case _:
            return nil
        }
    }

    private static
    func get(
        legacy trunk:String,
        stem:ArraySlice<String>,
        uri:URI) -> Self
    {
        var overload:Symbol.Decl? = nil
        var from:String? = nil

        for (key, value):(String, String) in uri.query?.parameters ?? []
        {
            switch key
            {
            case "overload":    overload = .init(rawValue: value)
            case "from":        from = value
            case _:             continue
            }
        }

        let query:ThinQuery<Volume.Shoot> = .legacy(head: trunk, rest: stem, from: from)

        if  let overload:Symbol.Decl
        {
            return .database(QueryOperation<ThinQuery<Symbol.Decl>>.init(
                explain: false,
                query: .init(volume: query.volume, lookup: overload),
                uri: uri))
        }
        else
        {
            return .database(QueryOperation<ThinQuery<Volume.Shoot>>.init(
                explain: false,
                query: query,
                uri: uri))
        }
    }
}

extension AnyOperation
{
    static
    func post(root:String, rest:ArraySlice<String>, form:MultipartForm?) -> Self?
    {
        guard root == Site.Action.root
        else
        {
            return nil
        }
        if  let action:String = rest.first,
            let action:Site.Action = .init(rawValue: action)
        {
            return .database(AdminOperation.perform(action, form))
        }
        else
        {
            return nil
        }
    }
}
