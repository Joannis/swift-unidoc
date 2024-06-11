
import BSON
import MD5
import MongoDB
import MongoQL
import UnidocDB
import UnidocRecords

@available(*, deprecated, renamed: "Unidoc.TextResourceQuery")
public
typealias SearchIndexQuery = Unidoc.TextResourceQuery

extension Unidoc
{
    /// A query that can avoid fetching the resource’s data if the hash matches.
    @frozen public
    struct TextResourceQuery<CollectionOrigin>:Equatable, Hashable, Sendable
        where CollectionOrigin:Mongo.CollectionModel
    {
        public
        let tag:MD5?
        public
        let id:CollectionOrigin.Element.ID

        @inlinable public
        init(tag:MD5?, id:CollectionOrigin.Element.ID)
        {
            self.tag = tag
            self.id = id
        }
    }
}
extension Unidoc.TextResourceQuery:Mongo.PipelineQuery
{
    public
    typealias Collation = VolumeCollation

    public
    typealias Iteration = Mongo.Single<Unidoc.TextResourceOutput>

    @inlinable public
    var hint:Mongo.CollectionIndex? { nil }

    public
    func build(pipeline:inout Mongo.PipelineEncoder)
    {
        typealias Document = Unidoc.TextResource<CollectionOrigin.Element.ID>

        pipeline[stage: .match]
        {
            $0[Document[.id]] = self.id
        }

        pipeline[stage: .set] = .init
        {
            $0[Unidoc.TextResourceOutput[.hash]] = Document[.hash]
            $0[Unidoc.TextResourceOutput[.text]] = .expr
            {
                if  let tag:MD5 = self.tag
                {
                    $0[.cond] =
                    (
                        if: .expr
                        {
                            $0[.eq] = (tag, Document[.hash])
                        },
                        then: .expr
                        {
                            $0[.binarySize] = .expr
                            {
                                $0[.coalesce] = (Document[.gzip], Document[.utf8])
                            }
                        },
                        else: .expr
                        {
                            $0[.coalesce] = (Document[.gzip], Document[.utf8])
                        }
                    )
                }
                else
                {
                    $0[.coalesce] = (Document[.gzip], Document[.utf8])
                }
            }
        }
    }
}
