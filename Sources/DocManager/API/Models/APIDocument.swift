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
