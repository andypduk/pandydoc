import Foundation

struct Document: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var fileName: String
    var fileExtension: String
    var documentType: DocumentType
    var status: DocumentStatus
    var checkedOutBy: String?
    var checkedOutAt: Date?
    var currentVersion: Int
    var fileSize: Int64
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    var notes: String
    var filePath: String
    var thumbnailPath: String?
    
    var isCheckedOut: Bool {
        status == .checkedOut
    }
    
    var isLocked: Bool {
        status == .locked
    }
    
    var isAvailable: Bool {
        status == .available
    }
    
    static func == (lhs: Document, rhs: Document) -> Bool {
        lhs.id == rhs.id
    }
    
    static func createNew(
        name: String,
        fileName: String,
        filePath: String,
        fileSize: Int64
    ) -> Document {
        let ext = (fileName as NSString).pathExtension
        return Document(
            id: UUID(),
            name: name,
            fileName: fileName,
            fileExtension: ext,
            documentType: DocumentType.from(extension: ext),
            status: .available,
            checkedOutBy: nil,
            checkedOutAt: nil,
            currentVersion: 1,
            fileSize: fileSize,
            createdAt: Date(),
            updatedAt: Date(),
            tags: [],
            notes: "",
            filePath: filePath,
            thumbnailPath: nil
        )
    }
}

struct DocumentVersion: Codable, Identifiable {
    let id: UUID
    let documentId: UUID
    let versionNumber: Int
    let fileName: String
    let filePath: String
    let fileSize: Int64
    let createdBy: String
    let createdAt: Date
    let checksum: String
    let changeNotes: String?
}

struct DocumentLock: Codable {
    let documentId: UUID
    let lockedBy: String
    let lockedAt: Date
    let expiresAt: Date
    var isActive: Bool {
        Date() < expiresAt
    }
}

struct CheckInRequest: Codable {
    let documentId: UUID
    let changeNotes: String?
    let filePath: String
}

struct CheckOutResponse: Codable {
    let success: Bool
    let document: Document?
    let tempFilePath: String?
    let error: String?
}
