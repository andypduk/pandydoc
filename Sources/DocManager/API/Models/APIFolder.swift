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
