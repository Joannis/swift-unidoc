import ModuleGraphs
import SemanticVersions
import UnidocQueries
import UnidocSelectors

extension ThinQuery<Selector.Lexical>
{
    static
    func legacy(
        head:String,
        rest:ArraySlice<String>,
        from:String? = nil) -> Self
    {
        func desugared(namespace:some StringProtocol) -> String?
        {
            switch namespace
            {
            case "concurrency":         return "_concurrency"
            case "differentiation":     return "_differentiation"
            case "dispatch":            return "dispatch"
            case "distributed":         return "distributed"
            case "foundation":          return "foundation"
            case "regexbuilder":        return "regexbuilder"
            case "regexparser":         return "_regexparser"
            case "stringprocessing":    return "_stringprocessing"
            case "swift":               return "swift"
            case _:                     return nil
            }
        }

        var package:PackageIdentifier = .swift
        var version:NumericVersion? = nil

        var head:String = head
        var rest:ArraySlice<String> = rest

        if  case true? = head.first?.isNumber,
            let next:String = rest.popFirst()
        {
            //  Legacy Biome urls also supported a weird nightly date version
            //  format (`reference/2022-8-24/swift`). Unidoc doesn’t distinguish
            //  between nightly snapshots unless explicitly tagged by the repo
            //  owner, so we just convert those to unversioned queries.
            version = .init(head)
            head = next
        }

        let stem:ArraySlice<String>

        if  let dot:String.Index = head.firstIndex(of: "."),
            let namespace:String = desugared(namespace: head[..<dot])
        {
            stem = ["\(namespace)\(head[dot...])"] + rest
        }
        else if
            let namespace:String = desugared(namespace: head)
        {
            stem = ["\(namespace)"] + rest
        }
        else
        {
            package = .init(head)
            stem = rest
        }

        if  let from:String
        {
            if  let slash:String.Index = from.firstIndex(of: "/")
            {
                package = .init(from[..<slash])
                version = .init(from[from.index(after: slash)...])
            }
            else
            {
                package = .init(from)
                version = nil
            }
        }

        return .init(for: .init(
                stem: stem,
                hash: nil),
            in: .init(
                package: package,
                version: version.map { "\(PatchVersion.init(padding: $0))" }))
    }
}
