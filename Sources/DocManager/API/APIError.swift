import Foundation
import HTTPTypes
import Hummingbird

enum APIError: Error, Equatable {
    case badRequest(String)
    case unauthorized
    case notFound(String)
    case conflict(String)
    case validationError(String)
    case internalError(String)

    var status: HTTPResponse.Status {
        switch self {
        case .badRequest: return .badRequest
        case .unauthorized: return .unauthorized
        case .notFound: return .notFound
        case .conflict: return .conflict
        case .validationError: return .unprocessableContent
        case .internalError: return .internalServerError
        }
    }

    var code: String {
        switch self {
        case .badRequest: return "bad_request"
        case .unauthorized: return "unauthorized"
        case .notFound: return "not_found"
        case .conflict: return "conflict"
        case .validationError: return "validation_error"
        case .internalError: return "internal_error"
        }
    }

    var message: String {
        switch self {
        case .badRequest(let msg), .notFound(let msg), .conflict(let msg), .validationError(let msg), .internalError(let msg):
            return msg
        case .unauthorized:
            return "Invalid or missing API key"
        }
    }
}

extension APIError: HTTPResponseError {
    func response(from request: Request, context: some RequestContext) throws -> Response {
        let body: String
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            let errorObj = ["error": ["code": code, "message": message]]
            let data = try encoder.encode(errorObj)
            body = String(data: data, encoding: .utf8) ?? ""
        } catch {
            body = "{\"error\":{\"code\":\"internal_error\",\"message\":\"Failed to encode error response\"}}"
        }
        var headers = HTTPFields()
        headers.append(HTTPField(name: .contentType, value: "application/json"))
        return Response(
            status: status,
            headers: headers,
            body: .init(byteBuffer: ByteBuffer(string: body))
        )
    }
}
