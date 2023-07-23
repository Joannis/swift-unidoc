import Media
import NIOCore
import NIOHTTP1
import SHA2

struct ServerMessage<Authority> where Authority:ServerAuthority
{
    let headers:HTTPHeaders
    let status:HTTPResponseStatus
    let body:ByteBuffer?

    private
    init(headers:HTTPHeaders, status:HTTPResponseStatus, body:ByteBuffer? = nil)
    {
        self.headers = headers
        self.status = status
        self.body = body
    }
}
extension ServerMessage
{
    init(redirect:__shared ServerRedirect)
    {
        var headers:HTTPHeaders = .init()

        headers.add(name: "host", value: Authority.domain)
        headers.add(name: "location", value: Authority.url(redirect.location))

        let status:HTTPResponseStatus
        switch redirect
        {
        case .permanent: status = .permanentRedirect
        case .temporary: status = .temporaryRedirect
        }

        self.init(headers: headers, status: status, body: nil)
    }

    init(resource:__shared ServerResource,
        using allocator:__shared ByteBufferAllocator,
        etag:__shared SHA256? = nil)
    {
        var headers:HTTPHeaders = .init()

        headers.add(name: "host", value: Authority.domain)

        let status:HTTPResponseStatus
        switch resource.results
        {
        case .error:
            status = .internalServerError

        case .none:
            status = .notFound

        case .many:
            status = .multipleChoices

        case .one(canonical: let location):

            if  let location:String
            {
                headers.add(name: "link", value: Authority.link(location, rel: .canonical))
            }

            guard let hash:SHA256 = resource.hash
            else
            {
                status = .ok
                break
            }

            headers.add(name: "etag", value: "\"\(hash)\"")

            if  case hash? = etag
            {
                status = .notModified
            }
            else
            {
                status = .ok
            }
        }

        let buffer:ByteBuffer?
        let length:Int
        switch resource.content
        {
        case .buffer(let bytes):
            length = bytes.readableBytes
            buffer = status == .notModified ? nil : bytes

        case .binary(let bytes):
            length = bytes.count
            buffer = status == .notModified ? nil : allocator.buffer(bytes: bytes)

        case .text(let string):
            length = string.utf8.count
            buffer = status == .notModified ? nil : allocator.buffer(string: string)
        }

        headers.add(name: "content-length", value: "\(length)")
        headers.add(name: "content-type",   value: "\(resource.type)")

        self.init(headers: headers, status: status, body: buffer)
    }

    init(redacting error:any Error,
        using allocator:__shared ByteBufferAllocator)
    {
        self.init(resource: .init(.error,
                content: .text(Authority.redact(error: error)),
                type: .text(.plain, charset: .utf8)),
            using: allocator)
    }
}
extension ServerMessage
{
    init(status:HTTPResponseStatus)
    {
        let buffer:ByteBuffer = .init(string: "\(status.code) (\(status.reasonPhrase))")
        var headers:HTTPHeaders = .init()

        headers.add(name: "host", value: Authority.domain)
        headers.add(name: "content-length", value: "\(buffer.readableBytes)")
        headers.add(name: "content-type",   value: "\(MediaType.text(.plain, charset: .utf8))")

        self.init(headers: headers, status: status, body: buffer)
    }
}
