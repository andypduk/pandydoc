import Foundation
import Hummingbird

struct DocumentController {
    private let storage = DocumentStorage.shared

    func registerRoutes(_ router: Router<some RequestContext>) {
        router.get("api/v1/documents", use: listDocuments)
        router.get("api/v1/documents/:id", use: getDocument)
        router.put("api/v1/documents/:id", use: updateDocument)
        router.delete("api/v1/documents/:id", use: deleteDocument)
        router.post("api/v1/documents/:id/move", use: moveDocument)
        router.post("api/v1/documents/:id/rename", use: renameDocument)
        router.post("api/v1/documents/:id/flag", use: toggleFlag)
        router.post("api/v1/documents/:id/protect", use: toggleProtect)
        router.post("api/v1/documents/:id/tags", use: addTag)
        router.delete("api/v1/documents/:id/tags/:tag", use: removeTag)
    }

    func listDocuments(_ request: Request, context: some RequestContext) async throws -> Response {
        let query = request.uri.queryParameters["search"].map { String($0) } ?? ""
        let folderIdStr = request.uri.queryParameters["folderId"].map { String($0) }
        let statusFilter = request.uri.queryParameters["status"].map { String($0) }
        let tagsFilter = request.uri.queryParameters["tags"].map { String($0).split(separator: ",").map(String.init) } ?? []
        let page = Int(request.uri.queryParameters["page"].map { String($0) } ?? "1") ?? 1
        let limit = min(Int(request.uri.queryParameters["limit"].map { String($0) } ?? "50") ?? 50, 200)

        var docs: [Document]
        if !query.isEmpty || !tagsFilter.isEmpty {
            docs = storage.searchDocuments(query: query, tags: tagsFilter)
        } else if let folderIdStr, let folderId = UUID(uuidString: folderIdStr) {
            docs = (try? storage.getDocumentsInFolder(folderID: folderId)) ?? []
        } else {
            docs = storage.getAllDocuments()
        }

        if let statusFilter {
            docs = docs.filter { $0.status.rawValue == statusFilter }
        }

        let total = docs.count
        let totalPages = max(1, (total + limit - 1) / limit)
        let start = (page - 1) * limit
        let end = min(start + limit, total)
        let pageDocs = start < total ? Array(docs[start..<end]) : []

        let apiDocs = pageDocs.map { APIDocument(from: $0) }
        let paginated = PaginatedResponse<APIDocument>(data: apiDocs, pagination: APIPagination(page: page, limit: limit, total: total, totalPages: totalPages))

        return try encodeJSON(paginated, context: context)
    }

    func getDocument(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard let doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        return try encodeJSON(APIDocument(from: doc), context: context)
    }

    func updateDocument(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard var doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }

        let body = try await request.decode(as: APIDocumentUpdateRequest.self, context: context)
        if let name = body.name {
            try InputValidation.validateName(name)
            doc.name = name
        }
        if let notes = body.notes {
            try InputValidation.validateNotes(notes)
            doc.notes = notes
        }
        if let tags = body.tags {
            try InputValidation.validateTags(tags)
            doc.tags = tags
        }
        doc.updatedAt = Date()

        try storage.updateDocument(doc)
        return try encodeJSON(APIDocument(from: doc), context: context)
    }

    func deleteDocument(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard let doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        if doc.protected {
            throw APIError.conflict("Document is protected")
        }
        try storage.deleteDocument(id: id)
        return Response(status: .noContent)
    }

    func moveDocument(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        let body = try await request.decode(as: APIMoveRequest.self, context: context)
        try storage.moveDocument(documentID: id, to: body.folderId)
        guard let doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        return try encodeJSON(APIDocument(from: doc), context: context)
    }

    func renameDocument(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard var doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        let body = try await request.decode(as: APIRenameRequest.self, context: context)
        try InputValidation.validateName(body.name)
        doc.name = body.name
        doc.updatedAt = Date()
        try storage.updateDocument(doc)
        return try encodeJSON(APIDocument(from: doc), context: context)
    }

    func toggleFlag(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard var doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        doc.flagged.toggle()
        doc.updatedAt = Date()
        try storage.updateDocument(doc)
        return try encodeJSON(APIDocument(from: doc), context: context)
    }

    func toggleProtect(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        try storage.toggleDocumentProtection(id: id)
        guard let doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        return try encodeJSON(APIDocument(from: doc), context: context)
    }

    func addTag(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard var doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        let body = try await request.decode(as: APITagRequest.self, context: context)
        try InputValidation.validateTag(body.tag)
        if !doc.tags.contains(body.tag) {
            doc.tags.append(body.tag)
            doc.updatedAt = Date()
            try storage.updateDocument(doc)
        }
        return try encodeJSON(APIDocument(from: doc), context: context)
    }

    func removeTag(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard let tag = context.parameters.get("tag") else {
            throw APIError.badRequest("Tag name required")
        }
        guard var doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        doc.tags.removeAll { $0 == tag }
        doc.updatedAt = Date()
        try storage.updateDocument(doc)
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
}
