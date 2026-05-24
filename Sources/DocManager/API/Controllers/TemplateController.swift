import Foundation
import Hummingbird

struct TemplateController {
    private let storage = DocumentStorage.shared

    func registerRoutes(_ router: Router<some RequestContext>) {
        router.get("api/v1/templates", use: listTemplates)
        router.post("api/v1/templates/:documentId/add", use: addToTemplates)
        router.delete("api/v1/templates/:documentId", use: removeFromTemplates)
    }

    func listTemplates(_ request: Request, context: some RequestContext) async throws -> Response {
        let folders = storage.getAllFolders()
        guard let templatesFolder = folders.first(where: { $0.name == "Templates" }) else {
            return try encodeJSON(["data": [APIDocument]()], context: context)
        }
        let docs = (try? storage.getDocumentsInFolder(folderID: templatesFolder.id)) ?? []
        return try encodeJSON(["data": docs.map { APIDocument(from: $0) }], context: context)
    }

    func addToTemplates(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("documentId", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard var doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        let folders = storage.getAllFolders()
        let templatesFolder: Folder
        if let existing = folders.first(where: { $0.name == "Templates" }) {
            templatesFolder = existing
        } else {
            templatesFolder = try storage.createFolder(name: "Templates", parentID: nil)
        }
        doc.parentID = templatesFolder.id
        doc.updatedAt = Date()
        try storage.updateDocument(doc)
        return try encodeJSON(APIDocument(from: doc), context: context)
    }

    func removeFromTemplates(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("documentId", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard var doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        doc.parentID = nil
        doc.updatedAt = Date()
        try storage.updateDocument(doc)
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
}
