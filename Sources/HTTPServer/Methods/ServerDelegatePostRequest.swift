import NIOCore
import NIOHTTP1

public
protocol ServerDelegatePostRequest:Sendable
{
    init?(_ uri:String,
        address:SocketAddress?,
        headers:HTTPHeaders,
        body:[UInt8],
        with promise:() -> EventLoopPromise<ServerResource>)
}
extension ServerDelegatePostRequest where Self == Never
{
    @inlinable public
    init?(_ uri:String,
        address:SocketAddress?,
        headers:HTTPHeaders,
        body:[UInt8],
        with _:() -> EventLoopPromise<ServerResource>)
    {
        nil
    }
}
