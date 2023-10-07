import Vapor
import OpenAPIRuntime

enum Streaming {

#if compiler(>=5.9)
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    actor Writer {
        let unownedExecutor: UnownedSerialExecutor
        let writer: any Vapor.BodyStreamWriter
        let body: OpenAPIRuntime.HTTPBody

        init(
            writer: any Vapor.BodyStreamWriter,
            body: OpenAPIRuntime.HTTPBody
        ) {
            self.unownedExecutor = writer.eventLoop.executor.asUnownedSerialExecutor()
            self.writer = writer
            self.body = body
        }

        func write() async {
            print("b do", Thread.current.name)
            do {
                print("a do", Thread.current.name)
                for try await chunk in body {
                    print("in for", Thread.current.name)
                    try await writer.write(.buffer(ByteBuffer(bytes: chunk))).get()
                    print("a for", Thread.current.name)
                }
                print("done for", Thread.current.name)
                try await writer.write(.end).get()
                print("ended", Thread.current.name)
            } catch {
                print("b err", Thread.current.name)
                try? await writer.write(.error(error)).get()
                print("a err", Thread.current.name)
            }
        }
    }
#endif // compiler(>=5.9)

    static func write(
        body: OpenAPIRuntime.HTTPBody,
        writer: any Vapor.BodyStreamWriter
    ) async {
#if compiler(>=5.9)
        if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
            await Writer(writer: writer, body: body).write()
            return
        }
#endif // compiler(>=5.9)
        await _writeWithHops(body: body, writer: writer)
    }

    static func _writeWithHops(
        body: OpenAPIRuntime.HTTPBody,
        writer: any Vapor.BodyStreamWriter
    ) async {
        do {
            for try await chunk in body {
                try await writer.eventLoop.flatSubmit {
                    writer.write(.buffer(ByteBuffer(bytes: chunk)))
                }.get()
            }
            try await writer.eventLoop.flatSubmit {
                writer.write(.end)
            }.get()
        } catch {
            try? await writer.eventLoop.flatSubmit {
                writer.write(.error(error))
            }.get()
        }
    }
}

extension EventLoopFuture {
    /// Get the value/error from an `EventLoopFuture` in an `async` context.
    ///
    /// This function can be used to bridge an `EventLoopFuture` into the `async` world. Ie. if you're in an `async`
    /// function and want to get the result of this future.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @inlinable
    public func getNew() async throws -> Value {
        print("get b withUnsafe", Thread.current.name)
        return try await withUnsafeThrowingContinuation { (cont: UnsafeContinuation<UnsafeTransfer<Value>, Error>) in
            print("get b whenComplete", Thread.current.name)
            self.whenComplete { result in
                print("get in whenComplete resume", Thread.current.name)
                switch result {
                case .success(let value):
                    print("get b succ resume", Thread.current.name)
                    cont.resume(returning: UnsafeTransfer(value))
                    print("get a succ resume", Thread.current.name)
                case .failure(let error):
                    print("get b fail resume", Thread.current.name)
                    cont.resume(throwing: error)
                    print("get a fail resume", Thread.current.name)
                }
                print("get out whenComplete", Thread.current.name)
            }
            print("get a whenComplete", Thread.current.name)
        }.wrappedValue
        print("get a withUnsafe", Thread.current.name)
    }
}

@usableFromInline
struct UnsafeTransfer<Wrapped> {
    @usableFromInline
    var wrappedValue: Wrapped

    @inlinable
    init(_ wrappedValue: Wrapped) {
        self.wrappedValue = wrappedValue
    }
}
