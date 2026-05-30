import Foundation
import HTTPTypes
import Hummingbird

extension HTTPField.Name {
    static let xAPIKey = Self("X-API-Key")!
    static let origin = Self("Origin")!
}

struct APIKeyAuthMiddleware<Context: RequestContext>: RouterMiddleware {
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        let exemptPaths = [
            "/api/v1/health",
            "/api/docs",
            "/api/openapi.json",
        ]
        
        if exemptPaths.contains(request.uri.path) {
            return try await next(request, context)
        }
        
        let apiKey = request.headers[.xAPIKey] ?? extractBearerToken(request)
        
        guard let key = apiKey, APIKeyManager.shared.validateKey(key) else {
            throw APIError.unauthorized
        }
        
        return try await next(request, context)
    }
    
    private func extractBearerToken(_ request: Request) -> String? {
        let auth = request.headers[.authorization] ?? ""
        if auth.hasPrefix("Bearer ") {
            return String(auth.dropFirst(7))
        }
        return nil
    }
}

struct CORSMiddleware<Context: RequestContext>: RouterMiddleware {
    private static var allowedOrigins: [String] {
        let stored = UserDefaults.standard.string(forKey: "corsAllowedOrigins") ?? ""
        if stored.isEmpty {
            return ["http://127.0.0.1", "http://localhost"]
        }
        return stored.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    private func originAllowed(_ origin: String) -> Bool {
        let allowed = Self.allowedOrigins
        return allowed.contains { origin == $0 || origin.hasPrefix($0 + ":") }
    }

    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        let origin = request.headers[.origin] ?? ""
        let allowOrigin = originAllowed(origin) ? origin : ""

        if request.method == .options {
            var headers = HTTPFields()
            if !allowOrigin.isEmpty {
                headers[.accessControlAllowOrigin] = allowOrigin
                headers[.accessControlAllowMethods] = "GET, POST, PUT, DELETE, OPTIONS"
                headers[.accessControlAllowHeaders] = "Content-Type, X-API-Key, Authorization"
            }
            return Response(status: .noContent, headers: headers)
        }

        var response = try await next(request, context)
        if !allowOrigin.isEmpty {
            response.headers[.accessControlAllowOrigin] = allowOrigin
        }
        return response
    }
}

struct ErrorHandlingMiddleware<Context: RequestContext>: RouterMiddleware {
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        do {
            return try await next(request, context)
        } catch let apiError as APIError {
            return try apiError.response(from: request, context: context)
        } catch {
            let internalError = APIError.internalError("An unexpected error occurred")
            return try internalError.response(from: request, context: context)
        }
    }
}
