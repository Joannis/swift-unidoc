import HTTP
import MD5
import MongoDB
import UnidocAssets
import UnidocRender

extension Unidoc
{
    @frozen public
    enum AnyOperation:Sendable
    {
        /// Runs with no ordering guarantees. Suspensions while serving the request might
        /// interleave with other requests.
        case unordered(any Unidoc.InteractiveOperation)
        /// Runs on the update loop, which is ordered with respect to other updates.
        case update(any Unidoc.ProceduralOperation)

        case syncError(String)
        case syncResource(any Unidoc.RenderablePage & Sendable)
        case syncRedirect(HTTP.Redirect)
        case syncLoad(Unidoc.Cache<Unidoc.Asset>.Request)
    }
}
extension Unidoc.AnyOperation
{
    static
    func explainable<Base>(_ endpoint:Base,
        parameters:Unidoc.PipelineParameters,
        etag:MD5?) -> Self
        where   Base:HTTP.ServerEndpoint<Unidoc.RenderFormat>,
                Base:Mongo.PipelineEndpoint,
                Base:Sendable
    {
        parameters.explain
        ? .unordered(Unidoc.LoadExplainedOperation<Base.Query>.init(query: endpoint.query))
        : .unordered(Unidoc.LoadOptimizedOperation<Base>.init(base: endpoint, etag: etag))
    }
}
