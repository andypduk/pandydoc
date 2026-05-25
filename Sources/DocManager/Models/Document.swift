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
    var parentID: UUID?
    var filePath: String?
    var thumbnailPath: String?
    var protected: Bool
    var flagged: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, fileName, fileExtension, documentType, status
        case checkedOutBy, checkedOutAt, currentVersion, fileSize
        case createdAt, updatedAt, tags, notes, parentID, filePath
        case thumbnailPath, protected, flagged
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        fileName = try container.decode(String.self, forKey: .fileName)
        fileExtension = try container.decode(String.self, forKey: .fileExtension)
        documentType = try container.decode(DocumentType.self, forKey: .documentType)
        status = try container.decode(DocumentStatus.self, forKey: .status)
        checkedOutBy = try container.decodeIfPresent(String.self, forKey: .checkedOutBy)
        checkedOutAt = try container.decodeIfPresent(Date.self, forKey: .checkedOutAt)
        currentVersion = try container.decode(Int.self, forKey: .currentVersion)
        fileSize = try container.decode(Int64.self, forKey: .fileSize)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        tags = try container.decode([String].self, forKey: .tags)
        notes = try container.decode(String.self, forKey: .notes)
        parentID = try container.decodeIfPresent(UUID.self, forKey: .parentID)
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        thumbnailPath = try container.decodeIfPresent(String.self, forKey: .thumbnailPath)
        protected = try container.decodeIfPresent(Bool.self, forKey: .protected) ?? false
        flagged = try container.decodeIfPresent(Bool.self, forKey: .flagged) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(fileExtension, forKey: .fileExtension)
        try container.encode(documentType, forKey: .documentType)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(checkedOutBy, forKey: .checkedOutBy)
        try container.encodeIfPresent(checkedOutAt, forKey: .checkedOutAt)
        try container.encode(currentVersion, forKey: .currentVersion)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(tags, forKey: .tags)
        try container.encode(notes, forKey: .notes)
        try container.encodeIfPresent(parentID, forKey: .parentID)
        try container.encodeIfPresent(filePath, forKey: .filePath)
        try container.encodeIfPresent(thumbnailPath, forKey: .thumbnailPath)
        try container.encode(protected, forKey: .protected)
        try container.encode(flagged, forKey: .flagged)
    }
    
    init(
        id: UUID,
        name: String,
        fileName: String,
        fileExtension: String,
        documentType: DocumentType,
        status: DocumentStatus,
        checkedOutBy: String?,
        checkedOutAt: Date?,
        currentVersion: Int,
        fileSize: Int64,
        createdAt: Date,
        updatedAt: Date,
        tags: [String],
        notes: String,
        parentID: UUID?,
        filePath: String?,
        thumbnailPath: String?,
        protected: Bool,
        flagged: Bool = false
    ) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.documentType = documentType
        self.status = status
        self.checkedOutBy = checkedOutBy
        self.checkedOutAt = checkedOutAt
        self.currentVersion = currentVersion
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.notes = notes
        self.parentID = parentID
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.protected = protected
        self.flagged = flagged
    }
    
    var isCheckedOut: Bool {
        status == .checkedOut
    }
    
    var isLocked: Bool {
        status == .locked
    }
    
    var isAvailable: Bool {
        status == .available
    }
    
    static func createNew(
        name: String,
        fileName: String,
        fileSize: Int64,
        parentID: UUID? = nil
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
            parentID: parentID,
            filePath: nil,
            thumbnailPath: nil,
            protected: false
        )
    }
}

struct DocumentVersion: Codable, Identifiable {
    let id: UUID
    let documentId: UUID
    let versionNumber: Int
    let fileName: String
    let filePath: String?
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
