import Foundation
import Hummingbird

struct DocsController {
    func registerRoutes(_ router: Router<some RequestContext>) {
        router.get("api/openapi.json", use: serveOpenAPI)
        router.get("api/docs", use: serveDocs)
        router.get("api/test-dashboard", use: serveTestDashboard)
    }

    func serveOpenAPI(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let url = Bundle.main.url(forResource: "openapi", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            throw APIError.internalError("OpenAPI spec not found")
        }
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(string: content))
        )
    }

    func serveDocs(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let url = Bundle.main.url(forResource: "docs", withExtension: "html"),
              let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            throw APIError.internalError("Documentation not found")
        }
        return Response(
            status: .ok,
            headers: [.contentType: "text/html"],
            body: .init(byteBuffer: ByteBuffer(string: content))
        )
    }

    func serveTestDashboard(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let url = Bundle.main.url(forResource: "test-dashboard", withExtension: "html"),
              let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            throw APIError.internalError("Test dashboard not found")
        }
        return Response(
            status: .ok,
            headers: [.contentType: "text/html"],
            body: .init(byteBuffer: ByteBuffer(string: content))
        )
    }
}
