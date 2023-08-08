import NIOCore
import NIOHTTP1
import SHA2

final
class ServerInterfaceHandler<Authority, Delegate>
    where Authority:ServerAuthority, Delegate:ServerDelegate
{
    private
    var request:(head:HTTPRequestHead, stream:[UInt8])?,
        responding:Bool,
        receiving:Bool
    private
    let delegate:Delegate
    private
    let address:SocketAddress?

    init(delegate:Delegate, address:SocketAddress?)
    {
        self.request = nil
        self.receiving = false
        self.responding = false

        self.delegate = delegate
        self.address = address
    }
}
extension ServerInterfaceHandler:ChannelInboundHandler, RemovableChannelHandler
{
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    func userInboundEventTriggered(context:ChannelHandlerContext, event:Any)
    {
        if  case .inputClosed? = event as? ChannelEvent
        {
            self.receiving = false
        }
        else
        {
            context.fireUserInboundEventTriggered(event)
            return
        }
        guard self.responding
        else
        {
            context.close(promise: nil)
            return
        }
    }

    func channelReadComplete(context:ChannelHandlerContext)
    {
        context.flush()
    }

    func channelRead(context:ChannelHandlerContext, data:NIOAny)
    {
        switch self.unwrapInboundIn(data)
        {
        case .head(let head):
            self.receiving = head.isKeepAlive
            switch head.method
            {
            case .GET:
                self.request = nil

                let request:Delegate.Request? = .init(get: head.uri,
                    address: self.address,
                    headers: head.headers)
                {
                    self.accept(context: context, etag: head.etag)
                }
                if  let request:Delegate.Request
                {
                    self.delegate.yield(request)
                }
                else
                {
                    self.send(message: .init(status: .badRequest), context: context)
                }

            case .POST:
                self.request = (head, .init())

            case _:
                self.send(message: .init(status: .methodNotAllowed), context: context)
            }

        case .body(let buffer):
            guard case (let head, var body)? = self.request
            else
            {
                break
            }

            self.request = nil

            //  16 MB size limit
            if  1 << 24 < body.count + buffer.readableBytes
            {
                self.send(message: .init(status: .payloadTooLarge), context: context)
            }
            else
            {
                //  is this slower than accumulating into another ByteBuffer, and then
                //  doing an explicit copy into a `[UInt8]`?
                //
                //  alternatively, can consumers adopt the neutral ABI provided by
                //  ``ByteBufferView.withUnsafeReadableBytesWithStorageManagement(_:)``?
                body.append(contentsOf: buffer.readableBytesView)
                self.request = (head, body)
            }

        case .end(_):
            guard case let (head, body)? = self.request
            else
            {
                // already responded
                break
            }

            self.request = nil

            let request:Delegate.Request? = .init(post: head.uri,
                    address: self.address,
                    headers: head.headers,
                    body: body)
            {
                self.accept(context: context, etag: head.etag)
            }
            if  let request:Delegate.Request
            {
                self.delegate.yield(request)
            }
            else
            {
                self.send(message: .init(status: .badRequest), context: context)
            }
        }
    }
}
extension ServerInterfaceHandler
{
    private
    func accept(context:ChannelHandlerContext,
        etag:SHA256?) -> EventLoopPromise<ServerResponse>
    {
        let promise:EventLoopPromise<ServerResponse> = context.eventLoop.makePromise(
            of: ServerResponse.self)

        promise.futureResult.whenComplete
        {
            switch $0
            {
            case .success(let response):
                switch response
                {
                case .redirect(let redirect):
                    self.send(message: .init(redirect: redirect),
                        context: context)

                case .resource(let resource):
                    self.send(message: .init(resource: resource,
                            using: context.channel.allocator,
                            etag: etag),
                        context: context)
                }

            case .failure(let error):
                self.send(message: .init(redacting: error, using: context.channel.allocator),
                    context: context)
            }
        }
        return promise
    }

    private
    func send(message:ServerMessage<Authority>, context:ChannelHandlerContext)
    {
        self.responding = true

        let sent:EventLoopPromise<Void> = context.eventLoop.makePromise(of: Void.self)
            sent.futureResult.whenComplete
        {
            _ in
            self.responding = false
            if !self.receiving
            {
                context.channel.close(promise: nil)
            }
        }

        context.write(self.wrapOutboundOut(.head(.init(version: .http1_1,
                status: message.status,
                headers: message.headers))),
            promise: nil)

        if  let body:ByteBuffer = message.body
        {
            context.write(self.wrapOutboundOut(.body(IOData.byteBuffer(body))),
                promise: nil)
        }

        context.writeAndFlush(self.wrapOutboundOut(.end(nil)),
            promise: sent)
    }
}
