import HTML
import LexicalPaths
import MarkdownABI
import MarkdownRendering
import SwiftinitRender
import Symbols

extension Swiftinit.VertexPageContext
{
    func vector<Display, Vector>(_ vector:Vector,
        display:Display) -> HTML.VectorLink<Display, Vector>?
        where Vector:Collection<Unidoc.Scalar>
    {
        vector.isEmpty ? nil : .init(self, display: display, scalars: vector)
    }
}
extension Swiftinit.VertexPageContext
{
    func card(decl id:Unidoc.Scalar) -> Swiftinit.DeclCard?
    {
        guard case (let vertex, let url?)? = self[decl: id]
        else
        {
            return nil
        }
        return .init(self, vertex: vertex, target: url)
    }

    func card(_ id:Unidoc.Scalar) -> Swiftinit.AnyCard?
    {
        switch self[vertex: id]
        {
        case (.article(let vertex), let url?)?:
            .article(.init(self, vertex: vertex, target: url))

        case (.culture(let vertex), let url?)?:
            .culture(.init(self, vertex: vertex, target: url))

        case (.decl(let vertex), let url?)?:
            .decl(.init(self, vertex: vertex, target: url))

        case (.product(let vertex), let url?)?:
            .product(.init(self, vertex: vertex, target: url))

        default:
            nil
        }
    }
}
extension Swiftinit.VertexPageContext
{
    func link(module:Unidoc.Scalar) -> HTML.Link<Symbol.Module>?
    {
        self[culture: module].map
        {
            .init(display: $0.module.id, target: $1)
        }
    }

    func link(decl:Unidoc.Scalar) -> HTML.Link<UnqualifiedPath>?
    {
        guard
        let (decl, url):(Unidoc.DeclVertex, String?) = self[decl: decl],
        let path:UnqualifiedPath = .init(splitting: decl.stem)
        else
        {
            return nil
        }

        return .init(display: path, target: url)
    }

    func link(article:Unidoc.Scalar) -> HTML.Link<Markdown.Bytecode.SafeView>?
    {
        self[article: article].map
        {
            .init(display: $0.headline.safe, target: $1)
        }
    }

    func link(source file:Unidoc.Scalar, line:Int? = nil) -> Swiftinit.SourceLink?
    {
        guard
        let refname:String = self[file.edition]?.refname,
        let vertex:Unidoc.FileVertex = self[file: file],
        let origin:Unidoc.PackageOrigin = self.repo?.origin
        else
        {
            return nil
        }

        let icon:Swiftinit.SourceLink.Icon
        let blob:String

        switch origin
        {
        case .github(let origin):
            icon = .github
            blob = "\(origin.https)/blob/\(refname)/\(vertex.symbol)"
        }

        return .init(target: line.map { "\(blob)#L\($0 + 1)" } ?? blob,
            icon: icon,
            file: vertex.symbol.last,
            line: line)
    }

    func link(media file:Unidoc.FileVertex) -> String?
    {
        guard
        let repo:Unidoc.PackageRepo = self.repo
        else
        {
            return nil
        }

        let refname:String = self[file.id.edition]?.refname ?? repo.master

        switch repo.origin
        {
        case .github(let origin):
            //  Files that lack a valid extension will not carry the correct `Content-Type`
            //  header, and won’t display correctly in the browser. There is no simple way to
            //  override this behavior, so files will just need to have the correct extension.
            guard
            let type:Substring = file.symbol.type
            else
            {
                return nil
            }

            let prefix:String

            switch type
            {
            case "gif":     prefix = "https://raw.githubusercontent.com"
            case "jpg":     prefix = "https://raw.githubusercontent.com"
            case "jpeg":    prefix = "https://raw.githubusercontent.com"
            case "png":     prefix = "https://raw.githubusercontent.com"
            case "svg":     prefix = "https://raw.githubusercontent.com"
            case "webp":    prefix = "https://media.githubusercontent.com/media"
            default:        return nil
            }

            return "\(prefix)/\(origin.owner)/\(origin.name)/\(refname)/\(file.symbol)"
        }
    }
}
