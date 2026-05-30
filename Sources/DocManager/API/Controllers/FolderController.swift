import Foundation
import Hummingbird

struct FolderController {
    private let storage = DocumentStorage.shared

    func registerRoutes(_ router: Router<some RequestContext>) {
        router.get("api/v1/folders", use: listFolders)
        router.get("api/v1/folders/:id", use: getFolder)
        router.post("api/v1/folders", use: createFolder)
        router.put("api/v1/folders/:id", use: updateFolder)
        router.delete("api/v1/folders/:id", use: deleteFolder)
        router.post("api/v1/folders/:id/move", use: moveFolder)
        router.post("api/v1/folders/:id/protect", use: toggleProtect)
        router.get("api/v1/folders/:id/documents", use: listDocumentsInFolder)
    }

    func listFolders(_ request: Request, context: some RequestContext) async throws -> Response {
        let parentId = request.uri.queryParameters["parentId"].flatMap { UUID(uuidString: String($0)) }
        let folders = (try? storage.getFolders(parentID: parentId)) ?? []
        return try encodeJSON(["data": folders.map { APIFolder(from: $0) }], context: context)
    }

    func getFolder(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid folder ID")
        }
        let folders = storage.getAllFolders()
        guard let folder = folders.first(where: { $0.id == id }) else {
            throw APIError.notFound("Folder not found")
        }
        return try encodeJSON(APIFolder(from: folder), context: context)
    }

    func createFolder(_ request: Request, context: some RequestContext) async throws -> Response {
        let body = try await request.decode(as: APIFolderCreateRequest.self, context: context)
        try InputValidation.validateName(body.name, field: "Folder name")
        let folder = try storage.createFolder(name: body.name, parentID: body.parentId)
        return try encodeJSON(APIFolder(from: folder), context: context)
    }

    func updateFolder(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid folder ID")
        }
        let folders = storage.getAllFolders()
        guard var folder = folders.first(where: { $0.id == id }) else {
            throw APIError.notFound("Folder not found")
        }
        let body = try await request.decode(as: APIFolderUpdateRequest.self, context: context)
        try InputValidation.validateName(body.name, field: "Folder name")
        folder.name = body.name
        folder.updatedAt = Date()
        try storage.updateFolder(folder)
        return try encodeJSON(APIFolder(from: folder), context: context)
    }

    func deleteFolder(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid folder ID")
        }
        let folders = storage.getAllFolders()
        if let folder = folders.first(where: { $0.id == id }), folder.protected {
            throw APIError.conflict("Folder is protected")
        }
        try storage.deleteFolder(id: id)
        return Response(status: .noContent)
    }

    func moveFolder(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid folder ID")
        }
        let body = try await request.decode(as: APIMoveRequest.self, context: context)
        try storage.moveFolder(id: id, to: body.folderId)
        let folders = storage.getAllFolders()
        guard let folder = folders.first(where: { $0.id == id }) else {
            throw APIError.notFound("Folder not found")
        }
        return try encodeJSON(APIFolder(from: folder), context: context)
    }

    func toggleProtect(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid folder ID")
        }
        try storage.toggleFolderProtection(id: id)
        let folders = storage.getAllFolders()
        guard let folder = folders.first(where: { $0.id == id }) else {
            throw APIError.notFound("Folder not found")
        }
        return try encodeJSON(APIFolder(from: folder), context: context)
    }

    func listDocumentsInFolder(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid folder ID")
        }
        let docs = (try? storage.getDocumentsInFolder(folderID: id)) ?? []
        return try encodeJSON(["data": docs.map { APIDocument(from: $0) }], context: context)
    }
}
