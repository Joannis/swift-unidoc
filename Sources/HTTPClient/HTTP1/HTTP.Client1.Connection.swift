import HTTP
import NIOCore

extension HTTP.Client1
{
    @frozen public
    struct Connection
    {
        @usableFromInline internal
        let channel:any Channel

        @inlinable internal
        init(channel:any Channel)
        {
            self.channel = channel
        }
    }
}
@available(*, unavailable, message: """
    HTTP.Client1.Connection is not Sendable.
    """)
extension HTTP.Client1.Connection:Sendable
{
}
extension HTTP.Client1.Connection
{
    @inlinable public
    func buffer(_ body:HTTP.Resource.Content.Body) -> ByteBuffer
    {
        switch body
        {
        case .buffer(let buffer):   buffer
        case .binary(let bytes):    self.channel.allocator.buffer(bytes: bytes)
        case .string(let string):   self.channel.allocator.buffer(string: string)
        }
    }
}
extension HTTP.Client1.Connection
{
    //  TODO: we could use the `content-length` header to avoid reallocating the destination
    //  buffer.
    public
    func fetch(_ request:__owned HTTP.Client1.Request) async throws -> HTTP.Client1.Facet
    {
        try await withThrowingTaskGroup(of: HTTP.Client1.Facet.self)
        {
            (tasks:inout ThrowingTaskGroup<HTTP.Client1.Facet, any Error>) in

            let channel:any Channel = self.channel

            tasks.addTask
            {
                try await withCheckedThrowingContinuation
                {
                    (promise:CheckedContinuation<HTTP.Client1.Facet, Error>) in

                    channel.writeAndFlush((promise, request)).whenFailure
                    {
                        promise.resume(throwing: $0)
                    }
                }
            }
            tasks.addTask
            {
                try await Task.sleep(for: .seconds(15))
                throw HTTP.RequestTimeoutError.init()
            }

            guard
            let facet:HTTP.Client1.Facet = try await tasks.next()
            else
            {
                throw HTTP.RequestTimeoutError.init()
            }

            tasks.cancelAll()
            return facet
        }
    }
}
