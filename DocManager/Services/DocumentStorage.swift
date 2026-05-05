import Foundation
import CommonCrypto

protocol DocumentStorageProtocol {
    func initializeStorage() throws
    func saveDocument(_ document: Document) throws
    func getDocument(id: UUID) -> Document?
    func getAllDocuments() -> [Document]
    func searchDocuments(query: String, tags: [String]) -> [Document]
    func deleteDocument(id: UUID) throws
    func updateDocument(_ document: Document) throws
    
    func createVersion(documentId: UUID, sourcePath: String, changeNotes: String?) throws -> DocumentVersion
    func getVersions(documentId: UUID) -> [DocumentVersion]
    func getVersion(documentId: UUID, versionNumber: Int) -> DocumentVersion?
    func restoreVersion(documentId: UUID, versionNumber: Int) throws -> String
    
    func storeReceivedPDF(sourcePath: String, fileName: String) throws -> Document
}

final class DocumentStorage: DocumentStorageProtocol {
    static let shared = DocumentStorage()
    
    private let fileManager = FileManager.default
    private var storageURL: URL
    private var documentsURL: URL
    private var versionsURL: URL
    private var metadataURL: URL
    private var documentsCache: [UUID: Document] = [:]
    private let queue = DispatchQueue(label: "com.pandydoc.storage", attributes: .concurrent)
    
    private init() {
        let fallbackDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("PandyDoc", isDirectory: true)
        
        do {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            storageURL = appSupport.appendingPathComponent("PandyDoc", isDirectory: true)
            try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
        } catch {
            print("Cannot access Application Support, using fallback: \(fallbackDir.path)")
            storageURL = fallbackDir
        }
        
        documentsURL = storageURL.appendingPathComponent("Documents", isDirectory: true)
        versionsURL = storageURL.appendingPathComponent("Versions", isDirectory: true)
        metadataURL = storageURL.appendingPathComponent("metadata.json", isDirectory: false)
    }
    
    func initializeStorage() throws {
        try createDirectoryIfNeeded(documentsURL)
        try createDirectoryIfNeeded(versionsURL)
        try loadMetadata()
    }
    
    func saveDocument(_ document: Document) throws {
        let destURL = documentsURL.appendingPathComponent("\(document.id.uuidString).\(document.fileExtension)")
        
        try queue.sync(flags: .barrier) {
            var caughtError: Error?
            
            if !self.fileManager.fileExists(atPath: destURL.path) {
                do {
                    try self.fileManager.copyItem(atPath: document.filePath, toPath: destURL.path)
                } catch {
                    caughtError = error
                }
            }
            
            if caughtError == nil {
                var doc = document
                doc.filePath = destURL.path
                self.documentsCache[doc.id] = doc
                do {
                    try self.saveMetadata()
                } catch {
                    caughtError = error
                }
            }
            
            if let caughtError {
                throw caughtError
            }
        }
    }
    
    func getDocument(id: UUID) -> Document? {
        queue.sync {
            documentsCache[id]
        }
    }
    
    func getAllDocuments() -> [Document] {
        queue.sync {
            Array(documentsCache.values).sorted { $0.updatedAt > $1.updatedAt }
        }
    }
    
    func searchDocuments(query: String, tags: [String]) -> [Document] {
        queue.sync {
            documentsCache.values.filter { doc in
                let matchesQuery = query.isEmpty ||
                    doc.name.localizedCaseInsensitiveContains(query) ||
                    doc.fileName.localizedCaseInsensitiveContains(query) ||
                    doc.tags.contains { $0.localizedCaseInsensitiveContains(query) }
                
                let matchesTags = tags.isEmpty || tags.allSatisfy { doc.tags.contains($0) }
                
                return matchesQuery && matchesTags
            }
            .sorted { $0.updatedAt > $1.updatedAt }
        }
    }
    
    func deleteDocument(id: UUID) throws {
        try queue.sync(flags: .barrier) {
            guard let doc = self.documentsCache[id] else { return }
            
            try? self.fileManager.removeItem(atPath: doc.filePath)
            let docVersionsURL = self.versionsURL.appendingPathComponent(doc.id.uuidString, isDirectory: true)
            try? self.fileManager.removeItem(atPath: docVersionsURL.path)
            
            self.documentsCache.removeValue(forKey: id)
            try? self.saveMetadata()
        }
    }
    
    func updateDocument(_ document: Document) throws {
        queue.sync(flags: .barrier) {
            self.documentsCache[document.id] = document
            try? self.saveMetadata()
        }
    }
    
    func createVersion(documentId: UUID, sourcePath: String, changeNotes: String?) throws -> DocumentVersion {
        guard let doc = documentsCache[documentId] else {
            throw DocumentError.documentNotFound
        }
        
        let versionDir = versionsURL.appendingPathComponent(documentId.uuidString, isDirectory: true)
        try createDirectoryIfNeeded(versionDir)
        
        let versionNumber = doc.currentVersion + 1
        let versionFileName = "v\(versionNumber)_\(doc.fileName)"
        let versionURL = versionDir.appendingPathComponent(versionFileName)
        
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
        
        var updatedDoc = doc
        updatedDoc.currentVersion = versionNumber
        updatedDoc.filePath = versionURL.path
        updatedDoc.updatedAt = Date()
        documentsCache[documentId] = updatedDoc
        
        try saveMetadata()
        return version
    }
    
    func getVersions(documentId: UUID) -> [DocumentVersion] {
        let versionDir = versionsURL.appendingPathComponent(documentId.uuidString, isDirectory: true)
        guard fileManager.fileExists(atPath: versionDir.path) else { return [] }
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: versionDir.path)
            return files.compactMap { fileName -> DocumentVersion? in
                let filePath = versionDir.appendingPathComponent(fileName).path
                let attributes = try? fileManager.attributesOfItem(atPath: filePath)
                return DocumentVersion(
                    id: UUID(),
                    documentId: documentId,
                    versionNumber: extractVersionNumber(from: fileName),
                    fileName: fileName,
                    filePath: filePath,
                    fileSize: attributes?[.size] as? Int64 ?? 0,
                    createdBy: NSFullUserName(),
                    createdAt: attributes?[.creationDate] as? Date ?? Date(),
                    checksum: "",
                    changeNotes: nil
                )
            }.sorted { $0.versionNumber > $1.versionNumber }
        } catch {
            return []
        }
    }
    
    func getVersion(documentId: UUID, versionNumber: Int) -> DocumentVersion? {
        getVersions(documentId: documentId).first { $0.versionNumber == versionNumber }
    }
    
    func restoreVersion(documentId: UUID, versionNumber: Int) throws -> String {
        guard let version = getVersion(documentId: documentId, versionNumber: versionNumber) else {
            throw DocumentError.versionNotFound
        }
        
        let docDir = documentsURL.appendingPathComponent(documentId.uuidString, isDirectory: true)
        try createDirectoryIfNeeded(docDir)
        
        let restoredPath = docDir.appendingPathComponent("v\(versionNumber)_\(version.fileName)").path
        try fileManager.copyItem(atPath: version.filePath, toPath: restoredPath)
        
        if let doc = documentsCache[documentId] {
            var updatedDoc = doc
            updatedDoc.currentVersion = versionNumber
            updatedDoc.filePath = restoredPath
            updatedDoc.fileSize = version.fileSize
            updatedDoc.updatedAt = Date()
            documentsCache[documentId] = updatedDoc
            try saveMetadata()
        }
        
        return restoredPath
    }
    
    func storeReceivedPDF(sourcePath: String, fileName: String) throws -> Document {
        let docName = (fileName as NSString).deletingPathExtension
        let sanitizedFileName = sanitizeFileName(fileName)
        
        let doc = Document.createNew(
            name: docName,
            fileName: sanitizedFileName,
            filePath: sourcePath,
            fileSize: 0
        )
        
        let destURL = documentsURL.appendingPathComponent("\(doc.id.uuidString).pdf")
        try fileManager.copyItem(atPath: sourcePath, toPath: destURL.path)
        
        let attributes = try fileManager.attributesOfItem(atPath: destURL.path)
        var savedDoc = doc
        savedDoc.filePath = destURL.path
        savedDoc.fileSize = attributes[.size] as? Int64 ?? 0
        savedDoc.documentType = .pdf
        
        queue.sync(flags: .barrier) {
            self.documentsCache[savedDoc.id] = savedDoc
            try? self.saveMetadata()
        }
        
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
    
    private func loadMetadata() throws {
        guard fileManager.fileExists(atPath: metadataURL.path) else { return }
        let data = try Data(contentsOf: metadataURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        documentsCache = try decoder.decode([UUID: Document].self, from: data)
    }
    
    private func saveMetadata() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(documentsCache)
        try data.write(to: metadataURL)
    }
    
    private func generateChecksum(_ path: String) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    private func extractVersionNumber(from fileName: String) -> Int {
        let regex = try? NSRegularExpression(pattern: "^v(\\d+)_")
        guard let match = regex?.firstMatch(in: fileName, range: NSRange(fileName.startIndex..., in: fileName)) else {
            return 0
        }
        guard let range = Range(match.range(at: 1), in: fileName) else { return 0 }
        return Int(fileName[range]) ?? 0
    }
    
    private func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?*<|:\"'")
        return name.components(separatedBy: invalidChars).joined()
    }
}
