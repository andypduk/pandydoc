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
