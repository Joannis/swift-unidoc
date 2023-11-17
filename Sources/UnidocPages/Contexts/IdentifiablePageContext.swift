import HTML
import LexicalPaths
import MarkdownABI
import ModuleGraphs
import Signatures
import Unidoc
import UnidocDB
import UnidocRecords

final
class IdentifiablePageContext<ID> where ID:Hashable
{
    /// Shared outlines, valid for the overview and details passages.
    var outlines:[Volume.Outline]

    private
    var cache:Cache

    let repo:Realm.Repo?

    private
    init(cache:Cache, repo:Realm.Repo?)
    {
        self.outlines = []
        self.cache = cache
        self.repo = repo
    }
}
extension IdentifiablePageContext:Identifiable
{
    var id:ID { self.vertices.principal }
}
extension IdentifiablePageContext
{
    var vertices:Vertices
    {
        _read   { yield  self.cache.vertices }
        _modify { yield &self.cache.vertices }
    }
    var volumes:Volumes
    {
        _read   { yield  self.cache.volumes }
        _modify { yield &self.cache.volumes }
    }
}
extension IdentifiablePageContext<Unidoc.Scalar>
{
    convenience
    init(principal scalar:Unidoc.Scalar, volume:Volume.Meta, repo:Realm.Repo?)
    {
        self.init(cache: .init(
                vertices: .init(principal: scalar),
                volumes: .init(principal: volume)),
            repo: repo)
    }
}
extension IdentifiablePageContext<Never?>
{
    convenience
    init(principal volume:Volume.Meta, repo:Realm.Repo?)
    {
        self.init(cache: .init(
                vertices: .init(principal: nil),
                volumes: .init(principal: volume)),
            repo: repo)
    }
}
extension IdentifiablePageContext where ID:VersionedPageIdentifier
{
    func prose(overview passage:Volume.Passage) -> ProseSection
    {
        .init(self, bytecode: passage.markdown, outlines: passage.outlines)
    }
    func prose(_ bytecode:MarkdownBytecode) -> ProseSection
    {
        //  We need to use the shared outlines, and not the array from the passage
        //  record, lest we make a frameshift indexing error.
        .init(self, bytecode: bytecode, outlines: self.outlines)
    }

    func code(_ snippet:Signature<Unidoc.Scalar?>.Expanded) -> CodeSection
    {
        .init(self, bytecode: snippet.bytecode, scalars: snippet.scalars)
    }

    func card(_ scalar:Unidoc.Scalar) -> GroupList.Card?
    {
        self.cache[scalar].map
        {
            .init(overview: $0.overview.map(self.prose(overview:)),
                vertex: $0,
                target: $1)
        }
    }
}
extension IdentifiablePageContext where ID:VersionedPageIdentifier
{
    func list(members:[Volume.Link], to list:inout HTML.ContentEncoder)
    {
        for member:Volume.Link in members
        {
            switch member
            {
            case .scalar(let scalar):
                list ?= self.card(scalar)

            case .text(let text):
                list[.li] { $0[.span] { $0[.code] = text } }
            }
        }
    }
}
extension IdentifiablePageContext where ID:VersionedPageIdentifier
{
    func link(module:Unidoc.Scalar) -> HTML.Link<ModuleIdentifier>?
    {
        self.cache[culture: module].map
        {
            .init(display: $0.module.id, target: $1)
        }
    }
    func link(decl:Unidoc.Scalar) -> HTML.Link<String>?
    {
        self.cache[decl: decl].map
        {
            let path:UnqualifiedPath? = .init(splitting: $0.stem)
            return .init(display: path?.description ?? "", target: $1)
        }
    }
    func link(file:Unidoc.Scalar, line:Int? = nil) -> HTML.SourceLink?
    {
        if  let origin:Realm.Repo.Origin = self.repo?.origin,
            let refname:String = self.volumes[file.zone]?.refname,
            let file:Volume.Vertex.File = self.vertices[file]?.file,
            let blob:String = origin.blob(refname: refname, file: file.symbol)
        {
            return .init(
                file: file.symbol.last,
                line: line,
                target: line.map { "\(blob)#L\($0 + 1)" } ?? blob)
        }
        else
        {
            return nil
        }
    }
}
extension IdentifiablePageContext:VersionedPageContext where ID:VersionedPageIdentifier
{
    func vector<Display, Vector>(_ vector:Vector,
        display:Display) -> HTML.VectorLink<Display, Vector>
        where Vector:Sequence<Unidoc.Scalar>
    {
        .init(self, display: display, scalars: vector)
    }

    func url(_ scalar:Unidoc.Scalar) -> String?
    {
        self.cache[scalar]?.url
    }

    var volume:Volume.Meta { self.volumes.principal }

    subscript(edition:Unidoc.Edition) -> Volume.Meta?
    {
        self.volumes[edition]
    }
}
