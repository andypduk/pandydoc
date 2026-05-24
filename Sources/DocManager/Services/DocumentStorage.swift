import Foundation
import SQLite
import CommonCrypto

protocol DocumentStorageProtocol {
    func initializeStorage() throws
    func saveDocument(_ document: Document) throws
    func getDocument(id: UUID) -> Document?
    func getAllDocuments() -> [Document]
    func searchDocuments(query: String, tags: [String]) -> [Document]
    func getAllTags() -> [(tag: String, count: Int)]
    func deleteDocument(id: UUID) throws
    func updateDocument(_ document: Document) throws
    
    func createVersion(documentId: UUID, sourcePath: String, changeNotes: String?) throws -> DocumentVersion
    func getVersions(documentId: UUID) -> [DocumentVersion]
    func getVersion(documentId: UUID, versionNumber: Int) -> DocumentVersion?
    func restoreVersion(documentId: UUID, versionNumber: Int) throws -> String
    
    func storeReceivedPDF(sourcePath: String, fileName: String, parentID: UUID?, tags: [String]) throws -> Document
    
    func getFolders(parentID: UUID?) throws -> [Folder]
    func getAllFolders() -> [Folder]
    func createFolder(name: String, parentID: UUID?) throws -> Folder
    func deleteFolder(id: UUID) throws
    func updateFolder(_ folder: Folder) throws
    func toggleFolderProtection(id: UUID) throws
    func moveFolder(id: UUID, to parentID: UUID?) throws
    func hasFolderWithName(name: String, parentID: UUID?, excluding: UUID?) throws -> Bool
    func isFolderProtected(id: UUID) throws -> Bool
    func toggleDocumentProtection(id: UUID) throws
    func getAllDocumentsRecursive() -> [Document]
    func getCheckedOutByUser(username: String) -> [Document]
    func getDocumentsInFolder(folderID: UUID) throws -> [Document]
    func moveDocument(documentID: UUID, to folderID: UUID?) throws
    func isSystemFolder(id: UUID) -> Bool
}

final class DocumentStorage: DocumentStorageProtocol {
    static let shared = DocumentStorage()
    
    private let fileManager = FileManager.default
    private var db: DatabaseManager
    private var documentsURL: URL
    private var versionsURL: URL
    
    private init(db: DatabaseManager = DatabaseManager.shared) {
        self.db = db
        
        documentsURL = db.storageURL.appendingPathComponent("Documents", isDirectory: true)
        versionsURL = db.storageURL.appendingPathComponent("Versions", isDirectory: true)
        
        print("PandyDoc storage: \(db.storageURL.path)")
    }
    
    func initializeStorage() throws {
        try db.connect()
        try createDirectoryIfNeeded(documentsURL)
        try createDirectoryIfNeeded(versionsURL)
    }
    
    func saveDocument(_ document: Document) throws {
        let conn = try db.getConnection()
        
        let destURL = documentsURL.appendingPathComponent("\(document.id.uuidString).\(document.fileExtension)")
        if !fileManager.fileExists(atPath: destURL.path) {
            try fileManager.copyItem(atPath: document.filePath, toPath: destURL.path)
        }
        
        var doc = document
        doc.filePath = destURL.path
        try db.insertDocument(db: conn, document: doc)
    }
    
    func getDocument(id: UUID) -> Document? {
        guard let conn = try? db.getConnection() else { return nil }
        return try? db.getDocument(db: conn, id: id)
    }
    
    func getAllDocuments() -> [Document] {
        guard let conn = try? db.getConnection() else { return [] }
        return (try? db.getAllDocuments(db: conn)) ?? []
    }
    
    func searchDocuments(query: String, tags: [String]) -> [Document] {
        guard let conn = try? db.getConnection() else { return [] }
        return (try? db.searchDocuments(db: conn, query: query, tags: tags)) ?? []
    }
    
    func getAllTags() -> [(tag: String, count: Int)] {
        guard let conn = try? db.getConnection() else { return [] }
        return (try? db.getAllTags(db: conn)) ?? []
    }
    
    func deleteDocument(id: UUID) throws {
        let conn = try db.getConnection()
        
        if let doc = getDocument(id: id) {
            try? fileManager.removeItem(atPath: doc.filePath)
            let docVersionsURL = versionsURL.appendingPathComponent(doc.id.uuidString, isDirectory: true)
            try? fileManager.removeItem(atPath: docVersionsURL.path)
        }
        
        try db.deleteDocument(db: conn, id: id)
    }
    
    func updateDocument(_ document: Document) throws {
        let conn = try db.getConnection()
        try db.updateDocument(db: conn, document: document)
    }
    
    func createVersion(documentId: UUID, sourcePath: String, changeNotes: String?) throws -> DocumentVersion {
        let conn = try db.getConnection()
        
        guard let doc = try db.getDocument(db: conn, id: documentId) else {
            throw DocumentError.documentNotFound
        }
        
        let versionDir = versionsURL.appendingPathComponent(documentId.uuidString, isDirectory: true)
        try createDirectoryIfNeeded(versionDir)
        
        let versionNumber = doc.currentVersion + 1
        let versionFileName = "v\(versionNumber)_\(doc.fileName)"
        let versionURL = versionDir.appendingPathComponent(versionFileName)
        
        if fileManager.fileExists(atPath: versionURL.path) {
            try fileManager.removeItem(atPath: versionURL.path)
        }
        try fileManager.copyItem(atPath: sourcePath, toPath: versionURL.path)
        let attributes = try fileManager.attributesOfItem(atPath: versionURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let checksum = try generateChecksum(sourcePath)
        
        let version = DocumentVersion(
            id: UUID(),
            documentId: documentId,
            versionNumber: versionNumber,
            fileName: versionFileName,
            filePath: versionURL.path,
            fileSize: fileSize,
            createdBy: NSFullUserName(),
            createdAt: Date(),
            checksum: checksum,
            changeNotes: changeNotes
        )
        
        try conn.transaction {
            try db.insertVersion(db: conn, version: version)
            
            var updatedDoc = doc
            updatedDoc.currentVersion = versionNumber
            updatedDoc.updatedAt = Date()
            try db.updateDocument(db: conn, document: updatedDoc)
        }
        
        NotificationCenter.default.post(
            name: .documentVersionCreated,
            object: nil,
            userInfo: ["documentId": documentId, "versionNumber": versionNumber]
        )
        
        return version
    }
    
    func getVersions(documentId: UUID) -> [DocumentVersion] {
        guard let conn = try? db.getConnection() else { return [] }
        return (try? db.getVersions(db: conn, documentId: documentId)) ?? []
    }
    
    func getVersion(documentId: UUID, versionNumber: Int) -> DocumentVersion? {
        guard let conn = try? db.getConnection() else { return nil }
        return try? db.getVersion(db: conn, documentId: documentId, versionNum: versionNumber)
    }
    
    func restoreVersion(documentId: UUID, versionNumber: Int) throws -> String {
        let conn = try db.getConnection()
        
        guard let version = try db.getVersion(db: conn, documentId: documentId, versionNum: versionNumber) else {
            throw DocumentError.versionNotFound
        }

        guard let doc = try db.getDocument(db: conn, id: documentId) else {
            throw DocumentError.documentNotFound
        }

        let destURL = URL(fileURLWithPath: doc.filePath)
        if fileManager.fileExists(atPath: destURL.path) {
            try fileManager.removeItem(at: destURL)
        }
        try fileManager.copyItem(atPath: version.filePath, toPath: destURL.path)

        let attributes = try fileManager.attributesOfItem(atPath: destURL.path)

        var updatedDoc = doc
        updatedDoc.currentVersion = versionNumber
        updatedDoc.fileSize = attributes[.size] as? Int64 ?? version.fileSize
        updatedDoc.updatedAt = Date()
        try db.updateDocument(db: conn, document: updatedDoc)

        return destURL.path
    }
    
    func storeReceivedPDF(sourcePath: String, fileName: String, parentID: UUID?, tags: [String]) throws -> Document {
        let conn = try db.getConnection()
        
        let docName = (fileName as NSString).deletingPathExtension
        let sanitizedFileName = sanitizeFileName(fileName)
        
        let normalizedTags = tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }
        
        var doc = Document.createNew(
            name: docName,
            fileName: sanitizedFileName,
            filePath: sourcePath,
            fileSize: 0,
            parentID: parentID
        )
        doc.tags.append(contentsOf: normalizedTags)
        
        let destURL = documentsURL.appendingPathComponent("\(doc.id.uuidString).pdf")
        try fileManager.copyItem(atPath: sourcePath, toPath: destURL.path)
        
        let attributes = try fileManager.attributesOfItem(atPath: destURL.path)
        var savedDoc = doc
        savedDoc.filePath = destURL.path
        savedDoc.fileSize = attributes[.size] as? Int64 ?? 0
        savedDoc.documentType = .pdf
        
        try db.insertDocument(db: conn, document: savedDoc)
        
        _ = try createVersion(
            documentId: savedDoc.id,
            sourcePath: destURL.path,
            changeNotes: "Received via Print to PandyDoc"
        )
        
        return savedDoc
    }
    
    private func createDirectoryIfNeeded(_ url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    private func generateChecksum(_ path: String) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    private func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?*<|:\"'")
        return name.components(separatedBy: invalidChars).joined()
    }

    // MARK: - Folders

    func getFolders(parentID: UUID?) throws -> [Folder] {
        let conn = try db.getConnection()
        return try db.getFolders(db: conn, parentID: parentID)
    }

    func getAllFolders() -> [Folder] {
        guard let conn = try? db.getConnection() else { return [] }
        return (try? db.getAllFolders(db: conn)) ?? []
    }

    func createFolder(name: String, parentID: UUID?) throws -> Folder {
        let conn = try db.getConnection()
        let folder = Folder(name: name, parentID: parentID)
        try db.insertFolder(db: conn, folder: folder)
        return folder
    }

    func deleteFolder(id: UUID) throws {
        let conn = try db.getConnection()
        try db.deleteFolder(db: conn, id: id)
    }

    func updateFolder(_ folder: Folder) throws {
        let conn = try db.getConnection()
        try db.updateFolder(db: conn, folder: folder)
    }

    func toggleFolderProtection(id: UUID) throws {
        let conn = try db.getConnection()
        try db.toggleFolderProtection(db: conn, id: id)
    }

    func moveFolder(id: UUID, to parentID: UUID?) throws {
        guard var folder = try getFolder(id: id) else {
            throw NSError(domain: "PandyDoc", code: 1, userInfo: [NSLocalizedDescriptionKey: "Folder not found"])
        }
        folder.parentID = parentID
        folder.updatedAt = Date()
        let conn = try db.getConnection()
        try db.updateFolder(db: conn, folder: folder)
    }

    func hasFolderWithName(name: String, parentID: UUID?, excluding excludeID: UUID?) throws -> Bool {
        let conn = try db.getConnection()
        return try db.hasFolderWithName(db: conn, name: name, parentID: parentID, excluding: excludeID)
    }

    func isFolderProtected(id: UUID) throws -> Bool {
        let conn = try db.getConnection()
        return try db.isFolderProtected(db: conn, id: id)
    }

    private func getFolder(id: UUID) throws -> Folder? {
        let conn = try db.getConnection()
        return try db.getFolder(db: conn, id: id)
    }

    func toggleDocumentProtection(id: UUID) throws {
        let conn = try db.getConnection()
        try db.toggleDocumentProtection(db: conn, id: id)
    }

    func isSystemFolder(id: UUID) -> Bool {
        return false
    }

    func getDocumentsInFolder(folderID: UUID) throws -> [Document] {
        let conn = try db.getConnection()
        return try db.getDocumentsInFolder(db: conn, folderID: folderID)
    }

    func getAllDocumentsRecursive() -> [Document] {
        guard let conn = try? db.getConnection() else { return [] }
        return (try? db.getAllDocumentsRecursive(db: conn)) ?? []
    }

    func getCheckedOutByUser(username: String) -> [Document] {
        guard let conn = try? db.getConnection() else { return [] }
        return (try? db.getCheckedOutByUser(db: conn, username: username)) ?? []
    }

    func moveDocument(documentID: UUID, to folderID: UUID?) throws {
        let conn = try db.getConnection()
        try db.moveDocument(db: conn, documentID: documentID, to: folderID)
    }
}
