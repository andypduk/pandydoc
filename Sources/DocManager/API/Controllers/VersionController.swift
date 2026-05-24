import Foundation
import Hummingbird

struct VersionController {
    private let storage = DocumentStorage.shared

    func registerRoutes(_ router: Router<some RequestContext>) {
        router.get("api/v1/documents/:id/versions", use: listVersions)
        router.get("api/v1/documents/:id/versions/:versionNumber", use: getVersion)
        router.post("api/v1/documents/:id/versions/:versionNumber/restore", use: restoreVersion)
    }

    func listVersions(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        let versions = storage.getVersions(documentId: id)
        let apiVersions = versions.map { APIVersion(from: $0) }
        return try encodeJSON(["data": apiVersions], context: context)
    }

    func getVersion(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard let versionNumber = Int(context.parameters.get("versionNumber") ?? "") else {
            throw APIError.badRequest("Invalid version number")
        }
        guard let version = storage.getVersion(documentId: id, versionNumber: versionNumber) else {
            throw APIError.notFound("Version not found")
        }
        return try encodeJSON(APIVersion(from: version), context: context)
    }

    func restoreVersion(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard let versionNumber = Int(context.parameters.get("versionNumber") ?? "") else {
            throw APIError.badRequest("Invalid version number")
        }
        try storage.restoreVersion(documentId: id, versionNumber: versionNumber)
        guard let doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
}
