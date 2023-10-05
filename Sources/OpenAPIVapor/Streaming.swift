import Vapor
import OpenAPIRuntime

enum Streaming {
    static func write(
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
