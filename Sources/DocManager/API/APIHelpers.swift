import Foundation
import Hummingbird

func encodeJSON<T: Codable>(_ value: T, context: some RequestContext) throws -> Response {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(value)
    let body = String(data: data, encoding: .utf8) ?? ""
    return Response(
        status: .ok,
        headers: [.contentType: "application/json"],
        body: .init(byteBuffer: ByteBuffer(string: body))
    )
}
