# PandyDoc REST API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Embed a Hummingbird-based REST API server inside the PandyDoc macOS app, exposing all features as RESTful endpoints with API key auth, interactive documentation, and two test applications.

**Architecture:** Hummingbird 2.x async HTTP server embedded in the existing DocManager target, sharing DatabaseManager and DocumentStorage singletons. Controllers delegate to existing services. Middleware pipeline handles auth, CORS, and error mapping.

**Tech Stack:** Hummingbird 2.x, Swift Concurrency, existing SQLite.swift + DocumentStorage + CheckInOutService + DatabaseManager

---

### Task 1: Add Hummingbird Dependency to Package.swift

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Add Hummingbird package dependency and target dependency**

Add Hummingbird to the dependencies array and as a dependency of DocManager:

```swift
// Package.swift - modify the dependencies array:
dependencies: [
    .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
],
```

```swift
// Package.swift - modify DocManager target dependencies:
.executableTarget(
    name: "DocManager",
    dependencies: [
        .product(name: "SQLite", package: "SQLite.swift"),
        .product(name: "Hummingbird", package: "hummingbird"),
    ],
    path: "Sources/DocManager",
    ...
),
```

- [ ] **Step 2: Verify build resolves dependencies**

Run: `swift package resolve`
Expected: Hummingbird and its dependencies downloaded and resolved

- [ ] **Step 3: Commit**

```bash
git add Package.swift Package.resolved
git commit -m "feat: add Hummingbird dependency for REST API"
```

---

### Task 2: Create API Error Types and Response Models

**Files:**
- Create: `Sources/DocManager/API/APIError.swift`
- Create: `Sources/DocManager/API/Models/APIPagination.swift`

- [ ] **Step 1: Create APIError type with HTTP status mapping**

```swift
// Sources/DocManager/API/APIError.swift
import Foundation
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
        return Response(
            status: status,
            headers: ["Content-Type": "application/json"],
            body: .init(byteBuffer: context.allocator.buffer(string: body))
        )
    }
}
```

- [ ] **Step 2: Create pagination response model**

```swift
// Sources/DocManager/API/Models/APIPagination.swift
import Foundation

struct APIPagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

struct PaginatedResponse<T: Codable>: Codable {
    let data: [T]
    let pagination: APIPagination
}
```

- [ ] **Step 3: Commit**

```bash
git add Sources/DocManager/API/
git commit -m "feat: add API error types and pagination models"
```

---

### Task 3: Create API Document/Folder DTOs

**Files:**
- Create: `Sources/DocManager/API/Models/APIDocument.swift`
- Create: `Sources/DocManager/API/Models/APIFolder.swift`
- Create: `Sources/DocManager/API/Models/APIVersion.swift`
- Create: `Sources/DocManager/API/Models/APISettings.swift`

- [ ] **Step 1: Create APIDocument DTO with conversion from Document model**

```swift
// Sources/DocManager/API/Models/APIDocument.swift
import Foundation

struct APIDocument: Codable {
    let id: UUID
    let name: String
    let fileName: String
    let fileExtension: String
    let documentType: String
    let status: String
    let checkedOutBy: String?
    let checkedOutAt: Date?
    let currentVersion: Int
    let fileSize: Int64
    let createdAt: Date
    let updatedAt: Date
    let tags: [String]
    let notes: String
    let parentID: UUID?
    let protected: Bool
    let flagged: Bool
    
    init(from document: Document) {
        self.id = document.id
        self.name = document.name
        self.fileName = document.fileName
        self.fileExtension = document.fileExtension
        self.documentType = document.documentType.rawValue
        self.status = document.status.rawValue
        self.checkedOutBy = document.checkedOutBy
        self.checkedOutAt = document.checkedOutAt
        self.currentVersion = document.currentVersion
        self.fileSize = document.fileSize
        self.createdAt = document.createdAt
        self.updatedAt = document.updatedAt
        self.tags = document.tags
        self.notes = document.notes
        self.parentID = document.parentID
        self.protected = document.protected
        self.flagged = document.flagged
    }
}

struct APIDocumentUpdateRequest: Codable {
    let name: String?
    let notes: String?
    let tags: [String]?
}

struct APIMoveRequest: Codable {
    let folderId: UUID?
}

struct APIRenameRequest: Codable {
    let name: String
}

struct APITagRequest: Codable {
    let tag: String
}

struct APICheckInRequest: Codable {
    let changeNotes: String?
    let filePath: String
}
```

- [ ] **Step 2: Create APIFolder DTO**

```swift
// Sources/DocManager/API/Models/APIFolder.swift
import Foundation

struct APIFolder: Codable {
    let id: UUID
    let name: String
    let parentID: UUID?
    let createdAt: Date
    let updatedAt: Date
    let protected: Bool
    
    init(from folder: Folder) {
        self.id = folder.id
        self.name = folder.name
        self.parentID = folder.parentID
        self.createdAt = folder.createdAt
        self.updatedAt = folder.updatedAt
        self.protected = folder.protected
    }
}

struct APIFolderCreateRequest: Codable {
    let name: String
    let parentId: UUID?
}

struct APIFolderUpdateRequest: Codable {
    let name: String
}
```

- [ ] **Step 3: Create APIVersion DTO**

```swift
// Sources/DocManager/API/Models/APIVersion.swift
import Foundation

struct APIVersion: Codable {
    let id: UUID
    let documentId: UUID
    let versionNumber: Int
    let fileName: String
    let fileSize: Int64
    let createdBy: String
    let createdAt: Date
    let checksum: String
    let changeNotes: String?
    
    init(from version: DocumentVersion) {
        self.id = version.id
        self.documentId = version.documentId
        self.versionNumber = version.versionNumber
        self.fileName = version.fileName
        self.fileSize = version.fileSize
        self.createdBy = version.createdBy
        self.createdAt = version.createdAt
        self.checksum = version.checksum
        self.changeNotes = version.changeNotes
    }
}
```

- [ ] **Step 4: Create APISettings DTO**

```swift
// Sources/DocManager/API/Models/APISettings.swift
import Foundation

struct APISettings: Codable {
    var autoCheckInOnAppClose: Bool
    var notifyOnDocumentChange: Bool
    var autoVersionOnSave: Bool
    var maxVersionsToKeep: Int
}

struct APISettingsUpdateRequest: Codable {
    let autoCheckInOnAppClose: Bool?
    let notifyOnDocumentChange: Bool?
    let autoVersionOnSave: Bool?
    let maxVersionsToKeep: Int?
}
```

- [ ] **Step 5: Commit**

```bash
git add Sources/DocManager/API/Models/
git commit -m "feat: add API DTOs for documents, folders, versions, settings"
```

---

### Task 4: Create API Middleware (Auth, CORS, Error Handling)

**Files:**
- Create: `Sources/DocManager/API/APIMiddleware.swift`
- Create: `Sources/DocManager/API/APIKeyManager.swift`

- [ ] **Step 1: Create APIKeyManager for key generation and storage**

```swift
// Sources/DocManager/API/APIKeyManager.swift
import Foundation
import CryptoKit

final class APIKeyManager {
    static let shared = APIKeyManager()
    
    private let defaults = UserDefaults.standard
    private let keyKey = "apiKey"
    
    var apiKey: String {
        if let existing = defaults.string(forKey: keyKey), !existing.isEmpty {
            return existing
        }
        let newKey = generateKey()
        defaults.set(newKey, forKey: keyKey)
        return newKey
    }
    
    func regenerateKey() -> String {
        let newKey = generateKey()
        defaults.set(newKey, forKey: keyKey)
        return newKey
    }
    
    func validateKey(_ key: String) -> Bool {
        key == apiKey
    }
    
    private func generateKey() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
```

- [ ] **Step 2: Create middleware pipeline**

```swift
// Sources/DocManager/API/APIMiddleware.swift
import Foundation
import Hummingbird

struct APIKeyAuthMiddleware: RouterMiddleware {
    func handleRequest(_ request: Request, context: some RequestContext, next: (Request, consuming: Bool) async throws -> Response) async throws -> Response {
        let exemptPaths = [
            "/api/v1/health",
            "/api/docs",
            "/api/openapi.json",
            "/api/test-dashboard",
        ]
        
        if exemptPaths.contains(request.uri.path) {
            return try await next(request, false)
        }
        
        let apiKey = request.headers["x-api-key"].first ?? extractBearerToken(request)
        
        guard let key = apiKey, APIKeyManager.shared.validateKey(key) else {
            throw APIError.unauthorized
        }
        
        return try await next(request, false)
    }
    
    private func extractBearerToken(_ request: Request) -> String? {
        let auth = request.headers["authorization"].first ?? ""
        if auth.hasPrefix("Bearer ") {
            return String(auth.dropFirst(7))
        }
        return nil
    }
}

struct CORSMiddleware: RouterMiddleware {
    func handleRequest(_ request: Request, context: some RequestContext, next: (Request, consuming: Bool) async throws -> Response) async throws -> Response {
        if request.method == .options {
            var response = Response(status: .noContent)
            response.headers["Access-Control-Allow-Origin"] = "*"
            response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
            response.headers["Access-Control-Allow-Headers"] = "Content-Type, X-API-Key, Authorization"
            return response
        }
        
        var response = try await next(request, false)
        response.headers["Access-Control-Allow-Origin"] = "*"
        return response
    }
}

struct ErrorHandlingMiddleware: RouterMiddleware {
    func handleRequest(_ request: Request, context: some RequestContext, next: (Request, consuming: Bool) async throws -> Response) async throws -> Response {
        do {
            return try await next(request, false)
        } catch let apiError as APIError {
            return try apiError.response(from: request, context: context)
        } catch {
            let internalError = APIError.internalError(error.localizedDescription)
            return try internalError.response(from: request, context: context)
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Sources/DocManager/API/APIMiddleware.swift Sources/DocManager/API/APIKeyManager.swift
git commit -m "feat: add API middleware for auth, CORS, error handling"
```

---

### Task 5: Create DocumentController

**Files:**
- Create: `Sources/DocManager/API/Controllers/DocumentController.swift`

- [ ] **Step 1: Create DocumentController with all document endpoints**

```swift
// Sources/DocManager/API/Controllers/DocumentController.swift
import Foundation
import Hummingbird

struct DocumentController {
    private let storage = DocumentStorage.shared
    private let checkInOut = CheckInOutService.shared
    
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
        let query = request.uri.queryParameters["search"]?.string ?? ""
        let folderIdStr = request.uri.queryParameters["folderId"]?.string
        let statusFilter = request.uri.queryParameters["status"]?.string
        let tagsFilter = request.uri.queryParameters["tags"]?.string?.split(separator: ",").map(String.init) ?? []
        let page = Int(request.uri.queryParameters["page"]?.string ?? "1") ?? 1
        let limit = min(Int(request.uri.queryParameters["limit"]?.string ?? "50") ?? 50, 200)
        
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
        let paginated = PaginatedResponse(data: apiDocs, pagination: APIPagination(page: page, limit: limit, total: total, totalPages: totalPages))
        
        return try encodeJSON(paginated, context: context)
    }
    
    func getDocument(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard let doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
    
    func updateDocument(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard var doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        
        let body = try await request.decode(from: JSONDecoder.self, as: APIDocumentUpdateRequest.self, context: context)
        if let name = body.name { doc.name = name }
        if let notes = body.notes { doc.notes = notes }
        if let tags = body.tags { doc.tags = tags }
        doc.updatedAt = Date()
        
        try storage.updateDocument(doc)
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
    
    func deleteDocument(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
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
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        let body = try await request.decode(from: JSONDecoder.self, as: APIMoveRequest.self, context: context)
        try storage.moveDocument(documentID: id, to: body.folderId)
        guard let doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
    
    func renameDocument(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard var doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        let body = try await request.decode(from: JSONDecoder.self, as: APIRenameRequest.self, context: context)
        doc.name = body.name
        doc.updatedAt = Date()
        try storage.updateDocument(doc)
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
    
    func toggleFlag(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
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
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        try storage.toggleDocumentProtection(id: id)
        guard let doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
    
    func addTag(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard var doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        let body = try await request.decode(from: JSONDecoder.self, as: APITagRequest.self, context: context)
        if !doc.tags.contains(body.tag) {
            doc.tags.append(body.tag)
            doc.updatedAt = Date()
            try storage.updateDocument(doc)
        }
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
    
    func removeTag(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard let tag = request.parameters.get("tag") else {
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
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/API/Controllers/DocumentController.swift
git commit -m "feat: add DocumentController with CRUD, move, rename, tag, flag, protect"
```

---

### Task 6: Create CheckInOutController

**Files:**
- Create: `Sources/DocManager/API/Controllers/CheckInOutController.swift`

- [ ] **Step 1: Create CheckInOutController**

```swift
// Sources/DocManager/API/Controllers/CheckInOutController.swift
import Foundation
import Hummingbird

struct CheckInOutController {
    private let checkInOut = CheckInOutService.shared
    private let storage = DocumentStorage.shared
    
    func registerRoutes(_ router: Router<some RequestContext>) {
        router.post("api/v1/documents/:id/checkout", use: checkOut)
        router.post("api/v1/documents/:id/checkin", use: checkIn)
        router.post("api/v1/documents/:id/save-working-copy", use: saveWorkingCopy)
        router.post("api/v1/documents/:id/discard-checkout", use: discardCheckout)
        router.post("api/v1/documents/:id/lock", use: lock)
        router.post("api/v1/documents/:id/unlock", use: unlock)
    }
    
    func checkOut(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        let response = try checkInOut.checkOut(documentId: id)
        guard response.success, let doc = response.document else {
            throw APIError.conflict(response.error ?? "Checkout failed")
        }
        return try encodeJSON(["document": APIDocument(from: doc), "tempFilePath": response.tempFilePath ?? ""], context: context)
    }
    
    func checkIn(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        let body = try await request.decode(from: JSONDecoder.self, as: APICheckInRequest.self, context: context)
        let doc = try checkInOut.checkIn(documentId: id, changeNotes: body.changeNotes)
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
    
    func saveWorkingCopy(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        let doc = try checkInOut.saveWorkingCopy(documentId: id)
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
    
    func discardCheckout(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        try checkInOut.discardCheckOut(documentId: id)
        return Response(status: .noContent)
    }
    
    func lock(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        try checkInOut.lock(documentId: id)
        guard let doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
    
    func unlock(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        try checkInOut.unlock(documentId: id)
        guard let doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/API/Controllers/CheckInOutController.swift
git commit -m "feat: add CheckInOutController"
```

---

### Task 7: Create VersionController, FolderController, TemplateController

**Files:**
- Create: `Sources/DocManager/API/Controllers/VersionController.swift`
- Create: `Sources/DocManager/API/Controllers/FolderController.swift`
- Create: `Sources/DocManager/API/Controllers/TemplateController.swift`

- [ ] **Step 1: Create VersionController**

```swift
// Sources/DocManager/API/Controllers/VersionController.swift
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
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        let versions = storage.getVersions(documentId: id)
        let apiVersions = versions.map { APIVersion(from: $0) }
        return try encodeJSON(["data": apiVersions], context: context)
    }
    
    func getVersion(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard let versionNumber = Int(request.parameters.get("versionNumber") ?? "") else {
            throw APIError.badRequest("Invalid version number")
        }
        guard let version = storage.getVersion(documentId: id, versionNumber: versionNumber) else {
            throw APIError.notFound("Version not found")
        }
        return try encodeJSON(APIVersion(from: version), context: context)
    }
    
    func restoreVersion(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        guard let versionNumber = Int(request.parameters.get("versionNumber") ?? "") else {
            throw APIError.badRequest("Invalid version number")
        }
        try storage.restoreVersion(documentId: id, versionNumber: versionNumber)
        guard let doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
}
```

- [ ] **Step 2: Create FolderController**

```swift
// Sources/DocManager/API/Controllers/FolderController.swift
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
        let parentIdStr = request.uri.queryParameters["parentId"]?.string
        let parentId = parentIdStr.flatMap { UUID(uuidString: $0) }
        let folders = (try? storage.getFolders(parentID: parentId)) ?? []
        let apiFolders = folders.map { APIFolder(from: $0) }
        return try encodeJSON(["data": apiFolders], context: context)
    }
    
    func getFolder(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid folder ID")
        }
        let folders = storage.getAllFolders()
        guard let folder = folders.first(where: { $0.id == id }) else {
            throw APIError.notFound("Folder not found")
        }
        return try encodeJSON(APIFolder(from: folder), context: context)
    }
    
    func createFolder(_ request: Request, context: some RequestContext) async throws -> Response {
        let body = try await request.decode(from: JSONDecoder.self, as: APIFolderCreateRequest.self, context: context)
        let folder = try storage.createFolder(name: body.name, parentID: body.parentId)
        return try encodeJSON(APIFolder(from: folder), context: context)
    }
    
    func updateFolder(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid folder ID")
        }
        let folders = storage.getAllFolders()
        guard var folder = folders.first(where: { $0.id == id }) else {
            throw APIError.notFound("Folder not found")
        }
        let body = try await request.decode(from: JSONDecoder.self, as: APIFolderUpdateRequest.self, context: context)
        folder.name = body.name
        folder.updatedAt = Date()
        try storage.updateFolder(folder)
        return try encodeJSON(APIFolder(from: folder), context: context)
    }
    
    func deleteFolder(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
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
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid folder ID")
        }
        let body = try await request.decode(from: JSONDecoder.self, as: APIMoveRequest.self, context: context)
        try storage.moveFolder(id: id, to: body.folderId)
        let folders = storage.getAllFolders()
        guard let folder = folders.first(where: { $0.id == id }) else {
            throw APIError.notFound("Folder not found")
        }
        return try encodeJSON(APIFolder(from: folder), context: context)
    }
    
    func toggleProtect(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("id", as: UUID.self) else {
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
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid folder ID")
        }
        let docs = (try? storage.getDocumentsInFolder(folderID: id)) ?? []
        let apiDocs = docs.map { APIDocument(from: $0) }
        return try encodeJSON(["data": apiDocs], context: context)
    }
}
```

- [ ] **Step 3: Create TemplateController**

```swift
// Sources/DocManager/API/Controllers/TemplateController.swift
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
            return try encodeJSON(["data": [APIDocument].self as [APIDocument]], context: context)
        }
        let docs = (try? storage.getDocumentsInFolder(folderID: templatesFolder.id)) ?? []
        let apiDocs = docs.map { APIDocument(from: $0) }
        return try encodeJSON(["data": apiDocs], context: context)
    }
    
    func addToTemplates(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = request.parameters.get("documentId", as: UUID.self) else {
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
        guard let id = request.parameters.get("documentId", as: UUID.self) else {
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
```

- [ ] **Step 4: Commit**

```bash
git add Sources/DocManager/API/Controllers/VersionController.swift Sources/DocManager/API/Controllers/FolderController.swift Sources/DocManager/API/Controllers/TemplateController.swift
git commit -m "feat: add VersionController, FolderController, TemplateController"
```

---

### Task 8: Create SearchController and SystemController

**Files:**
- Create: `Sources/DocManager/API/Controllers/SearchController.swift`
- Create: `Sources/DocManager/API/Controllers/SystemController.swift`

- [ ] **Step 1: Create SearchController**

```swift
// Sources/DocManager/API/Controllers/SearchController.swift
import Foundation
import Hummingbird

struct SearchController {
    private let storage = DocumentStorage.shared
    
    func registerRoutes(_ router: Router<some RequestContext>) {
        router.get("api/v1/search", use: search)
        router.get("api/v1/tags", use: tagCloud)
    }
    
    func search(_ request: Request, context: some RequestContext) async throws -> Response {
        let query = request.uri.queryParameters["q"]?.string ?? ""
        let docs = storage.searchDocuments(query: query, tags: [])
        let apiDocs = docs.map { APIDocument(from: $0) }
        return try encodeJSON(["data": apiDocs], context: context)
    }
    
    func tagCloud(_ request: Request, context: some RequestContext) async throws -> Response {
        let tags = storage.getAllTags()
        let tagData = tags.map { ["tag": $0.tag, "count": $0.count] }
        return try encodeJSON(["data": tagData], context: context)
    }
}
```

- [ ] **Step 2: Create SystemController**

```swift
// Sources/DocManager/API/Controllers/SystemController.swift
import Foundation
import Hummingbird

struct SystemController {
    private let dbManager = DatabaseManager.shared
    private let apiKeyManager = APIKeyManager.shared
    
    func registerRoutes(_ router: Router<some RequestContext>) {
        router.get("api/v1/health", use: health)
        router.get("api/v1/settings", use: getSettings)
        router.put("api/v1/settings", use: updateSettings)
        router.post("api/v1/vacuum", use: vacuum)
        router.get("api/v1/integrity", use: integrity)
        router.post("api/v1/auth/regenerate", use: regenerateKey)
    }
    
    func health(_ request: Request, context: some RequestContext) async throws -> Response {
        let body = ["status": "ok", "version": "1.0"]
        return try encodeJSON(body, context: context)
    }
    
    func getSettings(_ request: Request, context: some RequestContext) async throws -> Response {
        let settings = APISettings(
            autoCheckInOnAppClose: UserDefaults.standard.bool(forKey: "autoCheckInOnAppClose"),
            notifyOnDocumentChange: UserDefaults.standard.bool(forKey: "notifyOnDocumentChange"),
            autoVersionOnSave: UserDefaults.standard.bool(forKey: "autoVersionOnSave"),
            maxVersionsToKeep: UserDefaults.standard.integer(forKey: "maxVersionsToKeep")
        )
        return try encodeJSON(settings, context: context)
    }
    
    func updateSettings(_ request: Request, context: some RequestContext) async throws -> Response {
        let body = try await request.decode(from: JSONDecoder.self, as: APISettingsUpdateRequest.self, context: context)
        if let val = body.autoCheckInOnAppClose { UserDefaults.standard.set(val, forKey: "autoCheckInOnAppClose") }
        if let val = body.notifyOnDocumentChange { UserDefaults.standard.set(val, forKey: "notifyOnDocumentChange") }
        if let val = body.autoVersionOnSave { UserDefaults.standard.set(val, forKey: "autoVersionOnSave") }
        if let val = body.maxVersionsToKeep { UserDefaults.standard.set(val, forKey: "maxVersionsToKeep") }
        return try getSettings(request, context: context)
    }
    
    func vacuum(_ request: Request, context: some RequestContext) async throws -> Response {
        try dbManager.vacuum()
        return try encodeJSON(["status": "ok"], context: context)
    }
    
    func integrity(_ request: Request, context: some RequestContext) async throws -> Response {
        let result = try dbManager.integrityCheck()
        return try encodeJSON(["status": result ? "ok" : "failed", "details": result ? "Database integrity verified" : "Integrity issues found"], context: context)
    }
    
    func regenerateKey(_ request: Request, context: some RequestContext) async throws -> Response {
        let newKey = apiKeyManager.regenerateKey()
        return try encodeJSON(["apiKey": newKey], context: context)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Sources/DocManager/API/Controllers/SearchController.swift Sources/DocManager/API/Controllers/SystemController.swift
git commit -m "feat: add SearchController and SystemController"
```

---

### Task 9: Create API Routes and Server

**Files:**
- Create: `Sources/DocManager/API/APIRoutes.swift`
- Create: `Sources/DocManager/API/APIServer.swift`
- Create: `Sources/DocManager/API/APIHelpers.swift`

- [ ] **Step 1: Create APIHelpers for JSON encoding utility**

```swift
// Sources/DocManager/API/APIHelpers.swift
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
        headers: ["Content-Type": "application/json"],
        body: .init(byteBuffer: context.allocator.buffer(string: body))
    )
}
```

- [ ] **Step 2: Create APIRoutes**

```swift
// Sources/DocManager/API/APIRoutes.swift
import Hummingbird

func configureRoutes(_ router: Router<some RequestContext>) {
    let documentController = DocumentController()
    let checkInOutController = CheckInOutController()
    let versionController = VersionController()
    let folderController = FolderController()
    let templateController = TemplateController()
    let searchController = SearchController()
    let systemController = SystemController()
    let docsController = DocsController()
    
    documentController.registerRoutes(router)
    checkInOutController.registerRoutes(router)
    versionController.registerRoutes(router)
    folderController.registerRoutes(router)
    templateController.registerRoutes(router)
    searchController.registerRoutes(router)
    systemController.registerRoutes(router)
    docsController.registerRoutes(router)
}
```

- [ ] **Step 3: Create APIServer**

```swift
// Sources/DocManager/API/APIServer.swift
import Foundation
import Hummingbird

@MainActor
final class APIServer {
    static let shared = APIServer()
    
    private var server: HTTPServer?
    private var port: Int {
        get { UserDefaults.standard.integer(forKey: "apiPort") == 0 ? 8080 : UserDefaults.standard.integer(forKey: "apiPort") }
        set { UserDefaults.standard.set(newValue, forKey: "apiPort") }
    }
    
    var isRunning: Bool { server != nil }
    
    func start() async throws {
        guard !isRunning else { return }
        
        let router = Router()
        router.middlewares.add(CORSMiddleware())
        router.middlewares.add(APIKeyAuthMiddleware())
        router.middlewares.add(ErrorHandlingMiddleware())
        
        configureRoutes(router)
        
        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname("127.0.0.1", port: port),
                serverName: "PandyDoc API"
            )
        )
        
        try await app.start()
        server = app
        print("PandyDoc API server started on http://127.0.0.1:\(port)")
    }
    
    func stop() async {
        guard let server else { return }
        await server.shutdown()
        self.server = nil
        print("PandyDoc API server stopped")
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add Sources/DocManager/API/APIRoutes.swift Sources/DocManager/API/APIServer.swift Sources/DocManager/API/APIHelpers.swift
git commit -m "feat: add API routes, server, and helpers"
```

---

### Task 10: Create DocsController (OpenAPI + HTML Docs + Test Dashboard)

**Files:**
- Create: `Sources/DocManager/API/Controllers/DocsController.swift`
- Create: `Sources/DocManager/API/Docs/openapi.json`
- Create: `Sources/DocManager/API/Docs/docs.html`
- Create: `Sources/DocManager/API/Docs/test-dashboard.html`

- [ ] **Step 1: Create OpenAPI spec**

Create `Sources/DocManager/API/Docs/openapi.json` with the full OpenAPI 3.1 spec covering all endpoints defined in the design doc. The spec should include:
- All paths from the endpoint tables
- Request/response schemas for APIDocument, APIFolder, APIVersion, APISettings, PaginatedResponse
- API key security scheme (apiKey in header)
- Error response schema

- [ ] **Step 2: Create interactive HTML documentation**

Create `Sources/DocManager/API/Docs/docs.html` as a self-contained single-page HTML app with:
- Sidebar navigation grouped by resource
- Endpoint detail with method badges
- Collapsible JSON examples
- "Try It" panel with API key input
- Response viewer
- Copy as cURL button
- Dark mode support
- All CSS and JS inline, no external dependencies

- [ ] **Step 3: Create test dashboard HTML**

Create `Sources/DocManager/API/Docs/test-dashboard.html` as a self-contained HTML page with:
- API key input and connect button
- Collapsible test categories
- Run buttons (Run All, per-category)
- Live results with pass/fail indicators
- Response inspector
- Progress bar
- Export results as JSON

- [ ] **Step 4: Create DocsController to serve the static files**

```swift
// Sources/DocManager/API/Controllers/DocsController.swift
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
              let data = try? Data(contentsOf: url) else {
            throw APIError.internalError("OpenAPI spec not found")
        }
        return Response(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: .init(byteBuffer: context.allocator.buffer(data: Data(data)))
        )
    }
    
    func serveDocs(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let url = Bundle.main.url(forResource: "docs", withExtension: "html"),
              let data = try? Data(contentsOf: url) else {
            throw APIError.internalError("Documentation not found")
        }
        return Response(
            status: .ok,
            headers: ["Content-Type": "text/html"],
            body: .init(byteBuffer: context.allocator.buffer(data: Data(data)))
        )
    }
    
    func serveTestDashboard(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let url = Bundle.main.url(forResource: "test-dashboard", withExtension: "html"),
              let data = try? Data(contentsOf: url) else {
            throw APIError.internalError("Test dashboard not found")
        }
        return Response(
            status: .ok,
            headers: ["Content-Type": "text/html"],
            body: .init(byteBuffer: context.allocator.buffer(data: Data(data)))
        )
    }
}
```

- [ ] **Step 5: Register docs as resources in Package.swift**

Add to the DocManager target resources array:
```swift
resources: [
    .copy("../../Resources/PandaHead.icns"),
    .copy("../../Resources/PandaHead.pdf"),
    .process("API/Docs/openapi.json"),
    .process("API/Docs/docs.html"),
    .process("API/Docs/test-dashboard.html"),
],
```

- [ ] **Step 6: Commit**

```bash
git add Sources/DocManager/API/Controllers/DocsController.swift Sources/DocManager/API/Docs/ Package.swift
git commit -m "feat: add DocsController with OpenAPI spec, HTML docs, test dashboard"
```

---

### Task 11: Integrate API Server into App Lifecycle

**Files:**
- Modify: `Sources/DocManager/DocManagerApp.swift`
- Modify: `Sources/DocManager/Views/SettingsView.swift`

- [ ] **Step 1: Start API server in DocManagerApp**

Add to `DocManagerApp.swift`:
```swift
// After the @NSApplicationDelegateAdaptor line:
@State private var apiServerStarted = false

// Add to the body, in the WindowGroup .onAppear:
.onAppear {
    if !apiServerStarted {
        apiServerStarted = true
        Task {
            try? await APIServer.shared.start()
        }
    }
}
```

- [ ] **Step 2: Add API tab to SettingsView**

Add a new tab in the SettingsView TabView:
```swift
apiSettings
    .tabItem {
        Label("API", systemImage: "network")
    }
```

Create the `apiSettings` view with:
- API key display (masked with reveal toggle)
- Copy to clipboard button
- Regenerate key button with confirmation
- Server status indicator
- Port configuration field
- Start/Stop server toggle

- [ ] **Step 3: Commit**

```bash
git add Sources/DocManager/DocManagerApp.swift Sources/DocManager/Views/SettingsView.swift
git commit -m "feat: integrate API server into app lifecycle and settings"
```

---

### Task 12: Create CLI Test Harness

**Files:**
- Modify: `Package.swift` (add APITestCLI target)
- Create: `Sources/APITestCLI/main.swift`
- Create: `Sources/APITestCLI/APIClient.swift`
- Create: `Sources/APITestCLI/Assertions.swift`
- Create: `Sources/APITestCLI/Tests/*.swift`

- [ ] **Step 1: Add APITestCLI target to Package.swift**

```swift
.executableTarget(
    name: "APITestCLI",
    dependencies: [],
    path: "Sources/APITestCLI"
),
```

- [ ] **Step 2: Create APIClient**

```swift
// Sources/APITestCLI/APIClient.swift
import Foundation

struct APIClient {
    let baseURL: String
    let apiKey: String
    
    init(baseURL: String = "http://127.0.0.1:8080", apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
    
    func get(_ path: String) async throws -> (Data, HTTPURLResponse) {
        try await request(path, method: "GET")
    }
    
    func post(_ path: String, body: [String: Any]? = nil) async throws -> (Data, HTTPURLResponse) {
        try await request(path, method: "POST", body: body)
    }
    
    func put(_ path: String, body: [String: Any]? = nil) async throws -> (Data, HTTPURLResponse) {
        try await request(path, method: "PUT", body: body)
    }
    
    func delete(_ path: String) async throws -> (Data, HTTPURLResponse) {
        try await request(path, method: "DELETE")
    }
    
    private func request(_ path: String, method: String, body: [String: Any]? = nil) async throws -> (Data, HTTPURLResponse) {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            fatalError("Invalid response")
        }
        return (data, httpResponse)
    }
}
```

- [ ] **Step 3: Create Assertions**

```swift
// Sources/APITestCLI/Assertions.swift
import Foundation

func assertEqual(_ lhs: Any, _ rhs: Any, _ message: String) {
    if "\(lhs)" != "\(rhs)" {
        print("  ❌ \(message): expected \(rhs), got \(lhs)")
    }
}

func assertStatus(_ response: HTTPURLResponse, _ expected: Int, _ message: String) {
    if response.statusCode != expected {
        print("  ❌ \(message): expected status \(expected), got \(response.statusCode)")
    }
}

func assertJSON(_ data: Data, _ message: String) {
    do {
        let json = try JSONSerialization.jsonObject(with: data)
        print("  ✅ \(message)")
    } catch {
        print("  ❌ \(message): invalid JSON")
    }
}
```

- [ ] **Step 4: Create main.swift with test runner**

```swift
// Sources/APITestCLI/main.swift
import Foundation

let apiKey = ProcessInfo.processInfo.environment["API_KEY"] ?? {
    print("Error: API_KEY environment variable required")
    exit(1)
}()

let baseURL = ProcessInfo.processInfo.environment["BASE_URL"] ?? "http://127.0.0.1:8080"
let filterArg = CommandLine.arguments.dropFirst().first

let client = APIClient(baseURL: baseURL, apiKey: apiKey)

var passed = 0
var failed = 0

func runTest(_ name: String, _ test: () async throws -> Void) async {
    do {
        try await test()
        passed += 1
    } catch {
        print("  ❌ \(name): \(error.localizedDescription)")
        failed += 1
    }
}

@MainActor
func runAll() async {
    print("=== PandyDoc API Tests ===")
    print("Base URL: \(baseURL)")
    print("")
    
    if filterArg == nil || filterArg == "health" {
        print("--- Health ---")
        await runTest("Health check") {
            let (_, response) = try await client.get("/api/v1/health")
            assertStatus(response, 200, "Health check")
        }
    }
    
    if filterArg == nil || filterArg == "documents" {
        print("\n--- Documents ---")
        await runDocumentTests(client)
    }
    
    if filterArg == nil || filterArg == "folders" {
        print("\n--- Folders ---")
        await runFolderTests(client)
    }
    
    if filterArg == nil || filterArg == "versions" {
        print("\n--- Versions ---")
        await runVersionTests(client)
    }
    
    if filterArg == nil || filterArg == "checkout" {
        print("\n--- Check-In/Out ---")
        await runCheckInOutTests(client)
    }
    
    if filterArg == nil || filterArg == "search" {
        print("\n--- Search ---")
        await runSearchTests(client)
    }
    
    if filterArg == nil || filterArg == "system" {
        print("\n--- System ---")
        await runSystemTests(client)
    }
    
    print("\n─────────────────────────────────")
    print("Results: \(passed) passed, \(failed) failed, \(passed + failed) total")
    exit(failed > 0 ? 1 : 0)
}

Task { await runAll() }.wait()
```

- [ ] **Step 5: Create test files for each resource**

Create test files with actual test functions that exercise the API endpoints. Each test file should follow the pattern:
```swift
// Sources/APITestCLI/Tests/DocumentTests.swift
import Foundation

func runDocumentTests(_ client: APIClient) async {
    // Full lifecycle: create → read → update → move → rename → tag → flag → protect → delete
    // Each test creates, verifies, and cleans up
}
```

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/APITestCLI/
git commit -m "feat: add CLI test harness"
```

---

### Task 13: Build Verification and Final Integration

**Files:**
- All API files

- [ ] **Step 1: Build the project**

Run: `swift build 2>&1`
Expected: Clean build with no errors (warnings acceptable)

- [ ] **Step 2: Run CLI tests**

Start PandyDoc app, get API key from settings, then:
```bash
API_KEY=<key> swift run APITestCLI
```
Expected: All tests pass

- [ ] **Step 3: Verify documentation**

Open `http://127.0.0.1:8080/api/docs` in browser
Expected: Interactive HTML documentation loads

Open `http://127.0.0.1:8080/api/test-dashboard` in browser
Expected: Test dashboard loads

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete REST API integration"
```
