import Foundation
import SQLite
import SQLite3

typealias SQLiteExpression<T> = SQLite.Expression<T>

enum DatabaseError: Error, LocalizedError {
    case connectionFailed
    case migrationFailed(String)
    case queryFailed(String)
    case backupFailed(String)
    case restoreFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to database"
        case .migrationFailed(let msg):
            return "Database migration failed: \(msg)"
        case .queryFailed(let msg):
            return "Database query failed: \(msg)"
        case .backupFailed(let msg):
            return "Database backup failed: \(msg)"
        case .restoreFailed(let msg):
            return "Database restore failed: \(msg)"
        }
    }
}

final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: Connection?
    private(set) var dbURL: URL
    let storageURL: URL
    var databaseURL: URL { dbURL }
    var documentsURL: URL { storageURL.appendingPathComponent("Documents", isDirectory: true) }
    var versionsURL: URL { storageURL.appendingPathComponent("Versions", isDirectory: true) }
    
    private let documents = Table("documents")
    private let id = SQLite.Expression<String>("id")
    private let name = SQLite.Expression<String>("name")
    private let fileName = SQLite.Expression<String>("file_name")
    private let fileExtension = SQLite.Expression<String>("file_extension")
    private let documentType = SQLite.Expression<String>("document_type")
    private let status = SQLite.Expression<String>("status")
    private let checkedOutBy = SQLite.Expression<String?>("checked_out_by")
    private let checkedOutAt = SQLite.Expression<Date?>("checked_out_at")
    private let currentVersion = SQLite.Expression<Int>("current_version")
    private let fileSize = SQLite.Expression<Int64>("file_size")
    private let createdAt = SQLite.Expression<Date>("created_at")
    private let updatedAt = SQLite.Expression<Date>("updated_at")
    private let tags = SQLite.Expression<String>("tags")
    private let notes = SQLite.Expression<String>("notes")
    private let filePath = SQLite.Expression<String>("file_path")
    private let thumbnailPath = SQLite.Expression<String?>("thumbnail_path")
    private let parentIDCol = SQLite.Expression<String?>("parent_id")
    private let docProtected = SQLite.Expression<Bool>("protected")
    private let flagged = SQLite.Expression<Bool>("flagged")

    private let folders = Table("folders")
    private let folderId = SQLite.Expression<String>("id")
    private let folderName = SQLite.Expression<String>("name")
    private let folderParentId = SQLite.Expression<String?>("parent_id")
    private let folderCreatedAt = SQLite.Expression<Date>("created_at")
    private let folderUpdatedAt = SQLite.Expression<Date>("updated_at")
    private let folderProtected = SQLite.Expression<Bool>("protected")
    
    private let versions = Table("versions")
    private let versionId = SQLite.Expression<String>("id")
    private let documentId = SQLite.Expression<String>("document_id")
    private let versionNumber = SQLite.Expression<Int>("version_number")
    private let versionFileName = SQLite.Expression<String>("file_name")
    private let versionFilePath = SQLite.Expression<String>("file_path")
    private let versionFileSize = SQLite.Expression<Int64>("file_size")
    private let versionCreatedBy = SQLite.Expression<String>("created_by")
    private let versionCreatedAt = SQLite.Expression<Date>("created_at")
    private let versionChecksum = SQLite.Expression<String>("checksum")
    private let versionChangeNotes = SQLite.Expression<String?>("change_notes")
    
    private let metadata = Table("metadata")
    private let metaKey = SQLite.Expression<String>("key")
    private let metaValue = SQLite.Expression<String>("value")
    
    private init() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not locate Application Support directory")
        }
        storageURL = appSupport.appendingPathComponent("com.pandydoc.vault", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
        } catch {
            fatalError("Cannot create Application Support directory: \(error)")
        }

        dbURL = storageURL.appendingPathComponent("pandydoc.sqlite3")
        migrateFromLegacyPath()
        print("PandyDoc database: \(dbURL.path)")
    }

    private func migrateFromLegacyPath() {
        let legacyURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/PandyDoc/pandydoc.sqlite3")
        guard FileManager.default.fileExists(atPath: legacyURL.path),
              !FileManager.default.fileExists(atPath: dbURL.path) else { return }
        do {
            try FileManager.default.moveItem(at: legacyURL, to: dbURL)
            print("Migrated database from Documents to Application Support")
        } catch {
            print("Migration failed, copying instead: \(error)")
            try? FileManager.default.copyItem(at: legacyURL, to: dbURL)
        }
    }
    
    func connect() throws {
        guard db == nil else { return }
        db = try Connection(dbURL.path)
        try db!.execute("PRAGMA journal_mode=WAL")
        try db!.execute("PRAGMA synchronous=NORMAL")
        db!.busyTimeout = 5.0
        try runMigrations()
    }
    
    func getConnection() throws -> Connection {
        guard let db else {
            throw DatabaseError.connectionFailed
        }
        return db
    }

    func close() {
        db = nil
    }

    func checkpoint() {
        guard let db else { return }
        try? db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    }

    func vacuum() throws {
        checkpoint()
        guard let db else { throw DatabaseError.connectionFailed }
        try db.execute("VACUUM")
    }

    func databaseSize() -> Int64 {
        let fileManager = FileManager.default
        var size: Int64 = 0
        if fileManager.fileExists(atPath: dbURL.path) {
            size += (try? fileManager.attributesOfItem(atPath: dbURL.path)[.size] as? Int64) ?? 0
        }
        let walURL = URL(fileURLWithPath: dbURL.path + "-wal")
        if fileManager.fileExists(atPath: walURL.path) {
            size += (try? fileManager.attributesOfItem(atPath: walURL.path)[.size] as? Int64) ?? 0
        }
        let shmURL = URL(fileURLWithPath: dbURL.path + "-shm")
        if fileManager.fileExists(atPath: shmURL.path) {
            size += (try? fileManager.attributesOfItem(atPath: shmURL.path)[.size] as? Int64) ?? 0
        }
        return size
    }

    func eraseAll() throws {
        close()
        let walURL = URL(fileURLWithPath: dbURL.path + "-wal")
        let shmURL = URL(fileURLWithPath: dbURL.path + "-shm")
        for url in [dbURL, walURL, shmURL] {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
        let documentsDir = storageURL.appendingPathComponent("Documents", isDirectory: true)
        if FileManager.default.fileExists(atPath: documentsDir.path) {
            try FileManager.default.removeItem(at: documentsDir)
        }
        let versionsDir = storageURL.appendingPathComponent("Versions", isDirectory: true)
        if FileManager.default.fileExists(atPath: versionsDir.path) {
            try FileManager.default.removeItem(at: versionsDir)
        }
        try connect()
    }
    
    private func addColumnIfNotExists(db: Connection, tableName: String, columnName: String, type: String, defaultValue: String) {
        let sql = "ALTER TABLE \(tableName) ADD COLUMN \(columnName) \(type) DEFAULT \(defaultValue)"
        do {
            try db.execute(sql)
            print("Added column \(columnName) to \(tableName)")
        } catch {
            print("Column \(columnName) already exists or error: \(error)")
        }
    }
    
    private func runMigrations() throws {
        guard let db else { throw DatabaseError.connectionFailed }
        
        try db.run(metadata.create(ifNotExists: true) { t in
            t.column(metaKey, primaryKey: true)
            t.column(metaValue, unique: false)
        })
        
        let schemaQuery = metadata.filter(metaKey == "schema_version")
        let schemaVersion: String
        if let row = try? db.pluck(schemaQuery) {
            schemaVersion = row[metaValue]
        } else {
            schemaVersion = "0"
        }

        print("Database schema version: \(schemaVersion)")

        // Always try to add protected columns (fails silently if they exist)
        addColumnIfNotExists(db: db, tableName: "documents", columnName: "protected", type: "BOOLEAN", defaultValue: "0")
        addColumnIfNotExists(db: db, tableName: "folders", columnName: "protected", type: "BOOLEAN", defaultValue: "0")
        addColumnIfNotExists(db: db, tableName: "documents", columnName: "flagged", type: "BOOLEAN", defaultValue: "0")

        if schemaVersion == "4" {
            return
        }

        if schemaVersion == "0" {
            try db.run(documents.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(name)
                t.column(fileName)
                t.column(fileExtension)
                t.column(documentType)
                t.column(status)
                t.column(checkedOutBy)
                t.column(checkedOutAt)
                t.column(currentVersion, defaultValue: 1)
                t.column(fileSize, defaultValue: 0)
                t.column(createdAt)
                t.column(updatedAt)
                t.column(tags, defaultValue: "[]")
                t.column(notes, defaultValue: "")
                t.column(filePath)
                t.column(thumbnailPath)
            })

            try db.run(versions.create(ifNotExists: true) { t in
                t.column(versionId, primaryKey: true)
                t.column(documentId)
                t.column(versionNumber)
                t.column(versionFileName)
                t.column(versionFilePath)
                t.column(versionFileSize)
                t.column(versionCreatedBy)
                t.column(versionCreatedAt)
                t.column(versionChecksum)
                t.column(versionChangeNotes)
            })

            try db.run(documents.createIndex(status))
            try db.run(documents.createIndex(name))
            try db.run(versions.createIndex(documentId))
            try db.run(versions.createIndex(documentId, versionNumber, unique: true))
        }

        try db.run(folders.create(ifNotExists: true) { t in
            t.column(folderId, primaryKey: true)
            t.column(folderName)
            t.column(folderParentId)
            t.column(folderCreatedAt)
            t.column(folderUpdatedAt)
        })
        try db.run(folders.createIndex(folderParentId))

        addColumnIfNotExists(db: db, tableName: "documents", columnName: "parent_id", type: "TEXT", defaultValue: "NULL")
        addColumnIfNotExists(db: db, tableName: "documents", columnName: "protected", type: "BOOLEAN", defaultValue: "0")
        addColumnIfNotExists(db: db, tableName: "folders", columnName: "protected", type: "BOOLEAN", defaultValue: "0")
        addColumnIfNotExists(db: db, tableName: "documents", columnName: "flagged", type: "BOOLEAN", defaultValue: "0")

        try? migrateFromJSON(db: db)

        try db.run(metadata.insert(or: .replace,
            metaKey <- "schema_version",
            metaValue <- "4"
        ))
    }
    
    private func migrateFromJSON(db: Connection) throws {
        let count = try db.scalar(documents.count)
        guard count == 0 else { return }
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let fallbackDir = homeDir.appendingPathComponent("Documents/PandyDoc", isDirectory: true)
        
        var metadataPath: URL?
        
        let appSupportMeta = appSupport.appendingPathComponent("PandyDoc/metadata.json")
        if FileManager.default.fileExists(atPath: appSupportMeta.path) {
            metadataPath = appSupportMeta
        } else {
            let fallbackMeta = fallbackDir.appendingPathComponent("metadata.json")
            if FileManager.default.fileExists(atPath: fallbackMeta.path) {
                metadataPath = fallbackMeta
            }
        }
        
        guard let metaPath = metadataPath else { return }
        
        print("Migrating JSON data from \(metaPath.path)...")
        let data = try Data(contentsOf: metaPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let documentsCache = try decoder.decode([String: Document].self, from: data)
        
        try db.transaction {
            for (_, document) in documentsCache {
                try insertDocument(db: db, document: document)
            }
        }
        
        print("Migrated \(documentsCache.count) documents from JSON")
        try? FileManager.default.moveItem(at: metaPath, to: metaPath.appendingPathExtension("migrated"))
    }
    
    func insertDocument(db: Connection, document: Document) throws {
        let insert = documents.insert(
            id <- document.id.uuidString,
            name <- document.name,
            fileName <- document.fileName,
            fileExtension <- document.fileExtension,
            documentType <- document.documentType.rawValue,
            status <- document.status.rawValue,
            checkedOutBy <- document.checkedOutBy,
            checkedOutAt <- document.checkedOutAt,
            currentVersion <- document.currentVersion,
            fileSize <- document.fileSize,
            createdAt <- document.createdAt,
            updatedAt <- document.updatedAt,
            tags <- try JSONEncoder().encode(document.tags).base64EncodedString(),
            notes <- document.notes,
            parentIDCol <- document.parentID?.uuidString,
            filePath <- document.filePath,
            thumbnailPath <- document.thumbnailPath,
            docProtected <- document.protected,
            flagged <- document.flagged
        )
        try db.run(insert)
    }
    
    func updateDocument(db: Connection, document: Document) throws {
        let doc = documents.filter(id == document.id.uuidString)
        try db.run(doc.update(
            name <- document.name,
            fileName <- document.fileName,
            fileExtension <- document.fileExtension,
            documentType <- document.documentType.rawValue,
            status <- document.status.rawValue,
            checkedOutBy <- document.checkedOutBy,
            checkedOutAt <- document.checkedOutAt,
            currentVersion <- document.currentVersion,
            fileSize <- document.fileSize,
            createdAt <- document.createdAt,
            updatedAt <- document.updatedAt,
            tags <- try JSONEncoder().encode(document.tags).base64EncodedString(),
            notes <- document.notes,
            parentIDCol <- document.parentID?.uuidString,
            filePath <- document.filePath,
            thumbnailPath <- document.thumbnailPath,
            docProtected <- document.protected,
            flagged <- document.flagged
        ))
    }
    
    func getDocument(db: Connection, id: UUID) throws -> Document? {
        let doc = documents.filter(self.id == id.uuidString)
        guard let row = try db.pluck(doc) else { return nil }
        return try rowToDocument(row)
    }
    
    func getAllDocuments(db: Connection) throws -> [Document] {
        let query = documents.filter(parentIDCol == nil).order(updatedAt.desc)
        return try db.prepare(query).map { try rowToDocument($0) }
    }

    func getAllDocumentsRecursive(db: Connection) throws -> [Document] {
        let query = documents.order(updatedAt.desc)
        return try db.prepare(query).map { try rowToDocument($0) }
    }

    func getCheckedOutByUser(db: Connection, username: String) throws -> [Document] {
        let query = documents.filter(status == "checkedOut" && checkedOutBy == username)
            .order(updatedAt.desc)
        return try db.prepare(query).map { try rowToDocument($0) }
    }

    func getDocumentsInFolder(db: Connection, folderID: UUID) throws -> [Document] {
        let query = documents.filter(parentIDCol == folderID.uuidString).order(updatedAt.desc)
        return try db.prepare(query).map { try rowToDocument($0) }
    }
    
    func searchDocuments(db: Connection, query: String, tags: [String]) throws -> [Document] {
        var filteredQuery: QueryType = documents
        
        if !query.isEmpty {
            let pattern = "%\(query)%"
            let nameMatch = self.name.like(pattern)
            let fileNameMatch = self.fileName.like(pattern)
            filteredQuery = filteredQuery.filter(nameMatch || fileNameMatch)
        }
        
        var results = try db.prepare(filteredQuery.order(updatedAt.desc)).map { try rowToDocument($0) }
        
        if !tags.isEmpty {
            let normalizedFilterTags = tags.map { $0.lowercased() }
            results = results.filter { doc in
                let docTags = doc.tags.map { $0.lowercased() }
                return normalizedFilterTags.allSatisfy { filterTag in
                    docTags.contains { $0.contains(filterTag) || filterTag.contains($0) }
                }
            }
        }
        
        return results
    }
    
    func getAllTags(db: Connection) throws -> [(tag: String, count: Int)] {
        let allDocs = try db.prepare(documents).map { try rowToDocument($0) }
        var tagCounts: [String: Int] = [:]
        for doc in allDocs {
            for tag in doc.tags {
                let normalized = tag.lowercased()
                tagCounts[normalized, default: 0] += 1
            }
        }
        return tagCounts.sorted { $0.key < $1.key }.map { (tag: $0.key, count: $0.value) }
    }
    
    func deleteDocument(db: Connection, id: UUID) throws {
        let doc = documents.filter(self.id == id.uuidString)
        try db.run(doc.delete())
        
        let docVersions = versions.filter(documentId == id.uuidString)
        try db.run(docVersions.delete())
    }
    
    func insertVersion(db: Connection, version: DocumentVersion) throws {
        let insert = versions.insert(
            versionId <- version.id.uuidString,
            documentId <- version.documentId.uuidString,
            versionNumber <- version.versionNumber,
            versionFileName <- version.fileName,
            versionFilePath <- version.filePath,
            versionFileSize <- version.fileSize,
            versionCreatedBy <- version.createdBy,
            versionCreatedAt <- version.createdAt,
            versionChecksum <- version.checksum,
            versionChangeNotes <- version.changeNotes
        )
        try db.run(insert)
    }
    
    func getVersions(db: Connection, documentId: UUID) throws -> [DocumentVersion] {
        let query = versions.filter(self.documentId == documentId.uuidString)
            .order(versionNumber.desc)
        return try db.prepare(query).map { rowToVersion($0) }
    }
    
    func getVersion(db: Connection, documentId: UUID, versionNum: Int) throws -> DocumentVersion? {
        let query = versions.filter(self.documentId == documentId.uuidString && self.versionNumber == versionNum)
        guard let row = try db.pluck(query) else { return nil }
        return rowToVersion(row)
    }
    
    func deleteVersions(db: Connection, docId: UUID) throws {
        let docVersions = versions.filter(documentId == docId.uuidString)
        try db.run(docVersions.delete())
    }
    
    private func rowToDocument(_ row: Row) throws -> Document {
        let tagsData = try JSONSerialization.jsonObject(with: Data(base64Encoded: row[tags]) ?? Data()) as? [String]
        
        return Document(
            id: UUID(uuidString: row[id]) ?? UUID(),
            name: row[name],
            fileName: row[fileName],
            fileExtension: row[fileExtension],
            documentType: DocumentType(rawValue: row[documentType]) ?? .other,
            status: DocumentStatus(rawValue: row[status]) ?? .available,
            checkedOutBy: row[checkedOutBy],
            checkedOutAt: row[checkedOutAt],
            currentVersion: row[currentVersion],
            fileSize: row[fileSize],
            createdAt: row[createdAt],
            updatedAt: row[updatedAt],
            tags: tagsData ?? [],
            notes: row[notes],
            parentID: row[parentIDCol].flatMap { UUID(uuidString: $0) },
            filePath: row[filePath],
            thumbnailPath: row[thumbnailPath],
            protected: row[docProtected],
            flagged: row[flagged]
        )
    }
    
    private func rowToVersion(_ row: Row) -> DocumentVersion {
        DocumentVersion(
            id: UUID(uuidString: row[versionId]) ?? UUID(),
            documentId: UUID(uuidString: row[documentId]) ?? UUID(),
            versionNumber: row[versionNumber],
            fileName: row[versionFileName],
            filePath: row[versionFilePath],
            fileSize: row[versionFileSize],
            createdBy: row[versionCreatedBy],
            createdAt: row[versionCreatedAt],
            checksum: row[versionChecksum],
            changeNotes: row[versionChangeNotes]
        )
    }
    
    func getFolders(db: Connection, parentID: UUID?) throws -> [Folder] {
        let query: QueryType
        if let pid = parentID {
            query = folders.filter(folderParentId == pid.uuidString).order(folderName)
        } else {
            query = folders.filter(folderParentId == nil).order(folderName)
        }
        return try db.prepare(query).map { rowToFolder($0) }
    }

    func getAllFolders(db: Connection) throws -> [Folder] {
        let query = folders.order(folderName)
        return try db.prepare(query).map { rowToFolder($0) }
    }
    
    func getFolder(db: Connection, id: UUID) throws -> Folder? {
        let query = folders.filter(folderId == id.uuidString)
        guard let row = try db.pluck(query) else { return nil }
        return rowToFolder(row)
    }
    
    func insertFolder(db: Connection, folder: Folder) throws {
        let insert = folders.insert(
            folderId <- folder.id.uuidString,
            folderName <- folder.name,
            folderParentId <- folder.parentID?.uuidString,
            folderCreatedAt <- folder.createdAt,
            folderUpdatedAt <- folder.updatedAt,
            folderProtected <- folder.protected
        )
        try db.run(insert)
    }

    func updateFolder(db: Connection, folder: Folder) throws {
        let f = folders.filter(folderId == folder.id.uuidString)
        try db.run(f.update(
            folderName <- folder.name,
            folderParentId <- folder.parentID?.uuidString,
            folderUpdatedAt <- Date(),
            folderProtected <- folder.protected
        ))
    }
    
    func deleteFolder(db: Connection, id: UUID) throws {
        let folderFilter = folders.filter(folderId == id.uuidString)
        guard let existing = try db.pluck(folderFilter) else {
            throw DocumentError.documentNotFound
        }
        if existing[folderProtected] {
            throw DocumentError.protectedItem
        }

        let childFolders = try db.prepare(folders.filter(folderParentId == id.uuidString))
        for childRow in childFolders {
            let childId = UUID(uuidString: childRow[folderId]) ?? UUID()
            try deleteFolder(db: db, id: childId)
        }

        try db.run(folderFilter.delete())
        try db.run(documents.filter(parentIDCol == id.uuidString).update(parentIDCol <- nil))
    }

    func hasFolderWithName(db: Connection, name: String, parentID: UUID?, excluding excludeID: UUID?) throws -> Bool {
        var query = folders.filter(folderName == name)
        if let pid = parentID {
            query = query.filter(folderParentId == pid.uuidString)
        } else {
            query = query.filter(folderParentId == nil)
        }
        if let excludeID {
            query = query.filter(folderId != excludeID.uuidString)
        }
        return try db.scalar(query.count) > 0
    }

    func isFolderProtected(db: Connection, id: UUID) throws -> Bool {
        let query = folders.filter(folderId == id.uuidString)
        guard let row = try db.pluck(query) else {
            throw DocumentError.documentNotFound
        }
        return row[folderProtected]
    }

    func toggleFolderProtection(db: Connection, id: UUID) throws {
        let f = folders.filter(folderId == id.uuidString)
        guard let existing = try db.pluck(f) else { return }
        try db.run(f.update(folderProtected <- !existing[folderProtected]))
    }

    func toggleDocumentProtection(db: Connection, id: UUID) throws {
        let doc = documents.filter(self.id == id.uuidString)
        guard let existing = try db.pluck(doc) else { return }
        try db.run(doc.update(docProtected <- !existing[docProtected]))
    }
    
    private func rowToFolder(_ row: Row) -> Folder {
        Folder(
            id: UUID(uuidString: row[folderId]) ?? UUID(),
            name: row[folderName],
            parentID: row[folderParentId].flatMap { UUID(uuidString: $0) },
            createdAt: row[folderCreatedAt],
            updatedAt: row[folderUpdatedAt],
            protected: row[folderProtected]
        )
    }
    
    func moveDocument(db: Connection, documentID: UUID, to folderID: UUID?) throws {
        let doc = documents.filter(id == documentID.uuidString)
        try db.run(doc.update(parentIDCol <- folderID?.uuidString))
    }
    
    func integrityCheck() throws -> String {
        guard let db else { throw DatabaseError.connectionFailed }
        let stmt = try db.prepare("PRAGMA integrity_check")
        for row in stmt {
            return row[0] as? String ?? "unknown"
        }
        return "unknown"
    }
    
    func quickCheck() throws -> String {
        guard let db else { throw DatabaseError.connectionFailed }
        let stmt = try db.prepare("PRAGMA quick_check")
        for row in stmt {
            return row[0] as? String ?? "unknown"
        }
        return "unknown"
    }
    
    func foreignKeyCheck() throws -> [(table: String, rowid: Int64, parent: String, fkid: Int)] {
        guard let db else { throw DatabaseError.connectionFailed }
        let rows = try db.prepare("PRAGMA foreign_key_check")
        var results: [(table: String, rowid: Int64, parent: String, fkid: Int)] = []
        for row in rows {
            let table = row[0] as? String ?? "unknown"
            let rowid = row[1] as? Int64 ?? 0
            let parent = row[2] as? String ?? "unknown"
            let fkid = row[3] as? Int ?? 0
            results.append((table: table, rowid: rowid, parent: parent, fkid: fkid))
        }
        return results
    }
    
    func optimize() throws {
        guard let db else { throw DatabaseError.connectionFailed }
        try db.execute("PRAGMA optimize")
    }
    
    func liveBackup(to destinationDir: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: dbURL.path) else {
            throw DatabaseError.backupFailed("Database file does not exist")
        }
        guard let db else { throw DatabaseError.connectionFailed }
        
        try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        let destDBURL = destinationDir.appendingPathComponent("pandydoc.sqlite3")
        
        var destHandle: OpaquePointer?
        let openResult = sqlite3_open_v2(destDBURL.path, &destHandle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard openResult == SQLITE_OK, let destHandle else {
            throw DatabaseError.backupFailed("Could not create backup database")
        }
        defer { sqlite3_close(destHandle) }
        
        let backup = sqlite3_backup_init(destHandle, "main", db.handle, "main")
        guard let backup else {
            let errMsg = String(cString: sqlite3_errmsg(destHandle))
            throw DatabaseError.backupFailed(errMsg)
        }
        
        let stepResult = sqlite3_backup_step(backup, -1)
        sqlite3_backup_finish(backup)
        
        guard stepResult == SQLITE_DONE else {
            let errMsg = String(cString: sqlite3_errmsg(destHandle))
            throw DatabaseError.backupFailed("Backup step failed: \(errMsg)")
        }
        
        let documentsSrc = documentsURL
        if fileManager.fileExists(atPath: documentsSrc.path) {
            let documentsDest = destinationDir.appendingPathComponent("Documents", isDirectory: true)
            if fileManager.fileExists(atPath: documentsDest.path) {
                try fileManager.removeItem(at: documentsDest)
            }
            try fileManager.copyItem(at: documentsSrc, to: documentsDest)
        }
        
        let versionsSrc = versionsURL
        if fileManager.fileExists(atPath: versionsSrc.path) {
            let versionsDest = destinationDir.appendingPathComponent("Versions", isDirectory: true)
            if fileManager.fileExists(atPath: versionsDest.path) {
                try fileManager.removeItem(at: versionsDest)
            }
            try fileManager.copyItem(at: versionsSrc, to: versionsDest)
        }
    }
    
    func backupToiCloudDrive() throws -> URL? {
        guard let iCloudRoot = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        let backupDir = iCloudRoot.appendingPathComponent("Backups", isDirectory: true)
        try liveBackup(to: backupDir)
        return backupDir
    }
    
    func restore(from backupDir: URL) throws {
        let fileManager = FileManager.default
        let backupDBURL = backupDir.appendingPathComponent("pandydoc.sqlite3")
        guard fileManager.fileExists(atPath: backupDBURL.path) else {
            throw DatabaseError.restoreFailed("Backup database file does not exist")
        }
        close()
        let walURL = URL(fileURLWithPath: dbURL.path + "-wal")
        let shmURL = URL(fileURLWithPath: dbURL.path + "-shm")
        let backupWalURL = URL(fileURLWithPath: backupDBURL.path + "-wal")
        let backupShmURL = URL(fileURLWithPath: backupDBURL.path + "-shm")
        for url in [dbURL, walURL, shmURL] {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
        do {
            try fileManager.copyItem(at: backupDBURL, to: dbURL)
            if fileManager.fileExists(atPath: backupWalURL.path) {
                try fileManager.copyItem(at: backupWalURL, to: URL(fileURLWithPath: dbURL.path + "-wal"))
            }
            if fileManager.fileExists(atPath: backupShmURL.path) {
                try fileManager.copyItem(at: backupShmURL, to: URL(fileURLWithPath: dbURL.path + "-shm"))
            }
        } catch {
            throw DatabaseError.restoreFailed(error.localizedDescription)
        }
        let backupDocuments = backupDir.appendingPathComponent("Documents", isDirectory: true)
        if fileManager.fileExists(atPath: backupDocuments.path) {
            if fileManager.fileExists(atPath: documentsURL.path) {
                try fileManager.removeItem(at: documentsURL)
            }
            try fileManager.copyItem(at: backupDocuments, to: documentsURL)
        }
        let backupVersions = backupDir.appendingPathComponent("Versions", isDirectory: true)
        if fileManager.fileExists(atPath: backupVersions.path) {
            if fileManager.fileExists(atPath: versionsURL.path) {
                try fileManager.removeItem(at: versionsURL)
            }
            try fileManager.copyItem(at: backupVersions, to: versionsURL)
        }
        try connect()
    }
}
