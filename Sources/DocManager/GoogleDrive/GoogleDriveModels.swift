import Foundation

struct GDriveItem: Codable, Identifiable {
    let id: String
    let name: String
    let mimeType: String
    let size: Int64?
    let parents: [String]?
    let downloadURL: String?

    var isFolder: Bool {
        mimeType == "application/vnd.google-apps.folder"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, mimeType, size, parents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        mimeType = try container.decode(String.self, forKey: .mimeType)
        size = try container.decodeIfPresent(Int64.self, forKey: .size)
        parents = try container.decodeIfPresent([String].self, forKey: .parents)
        downloadURL = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(parents, forKey: .parents)
    }
}

struct GDriveFileList: Codable {
    let items: [GDriveItem]
    let nextPageToken: String?

    enum CodingKeys: String, CodingKey {
        case items = "files"
        case nextPageToken
    }
}
