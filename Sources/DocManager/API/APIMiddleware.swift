import Foundation
import HTTPTypes
import Hummingbird

extension HTTPField.Name {
    static let xAPIKey = Self("X-API-Key")!
}

struct APIKeyAuthMiddleware<Context: RequestContext>: RouterMiddleware {
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        let exemptPaths = [
            "/api/v1/health",
            "/api/docs",
            "/api/openapi.json",
            "/api/test-dashboard",
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
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        if request.method == .options {
            var headers = HTTPFields()
            headers[.accessControlAllowOrigin] = "*"
            headers[.accessControlAllowMethods] = "GET, POST, PUT, DELETE, OPTIONS"
            headers[.accessControlAllowHeaders] = "Content-Type, X-API-Key, Authorization"
            return Response(status: .noContent, headers: headers)
        }
        
        var response = try await next(request, context)
        response.headers[.accessControlAllowOrigin] = "*"
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
            let internalError = APIError.internalError(error.localizedDescription)
            return try internalError.response(from: request, context: context)
        }
    }
}
