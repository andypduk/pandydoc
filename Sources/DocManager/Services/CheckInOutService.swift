import Foundation

enum DocumentError: Error, LocalizedError {
    case documentNotFound
    case documentAlreadyCheckedOut
    case documentNotCheckedOut
    case documentLockedByOther
    case versionNotFound
    case fileNotFound
    case unauthorized
    case storageError(String)
    case checkoutFailed(String)
    case protectedItem
    
    var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "Document not found"
        case .documentAlreadyCheckedOut:
            return "Document is already checked out by another user"
        case .documentNotCheckedOut:
            return "Document is not checked out"
        case .documentLockedByOther:
            return "Document is locked by another user"
        case .versionNotFound:
            return "Version not found"
        case .fileNotFound:
            return "File not found"
        case .unauthorized:
            return "You are not authorized to perform this action"
        case .storageError(let msg):
            return "Storage error: \(msg)"
        case .checkoutFailed(let msg):
            return "Checkout failed: \(msg)"
        case .protectedItem:
            return "This item is protected and cannot be deleted"
        }
    }
}

protocol CheckInOutProtocol {
    func checkOut(documentId: UUID) throws -> CheckOutResponse
    func checkIn(documentId: UUID, changeNotes: String?) throws -> Document
    func saveWorkingCopy(documentId: UUID) throws -> Document
    func discardCheckOut(documentId: UUID) throws
    func lock(documentId: UUID) throws
    func unlock(documentId: UUID) throws
    func canEdit(documentId: UUID) -> Bool
}

final class CheckInOutService: CheckInOutProtocol {
    static let shared = CheckInOutService()
    
    private let storage: DocumentStorageProtocol
    private let fileManager = FileManager.default
    private var tempDir: URL
    
    private init(storage: DocumentStorageProtocol = DocumentStorage.shared) {
        self.storage = storage
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PandyDoc/Editing", isDirectory: true)
    }
    
    func checkOut(documentId: UUID) throws -> CheckOutResponse {
        guard let document = storage.getDocument(id: documentId) else {
            return CheckOutResponse(success: false, document: nil, tempFilePath: nil, error: DocumentError.documentNotFound.localizedDescription)
        }
        
        if document.isLocked {
            return CheckOutResponse(success: false, document: nil, tempFilePath: nil, error: DocumentError.documentLockedByOther.localizedDescription)
        }
        
        if document.isCheckedOut && document.checkedOutBy != NSFullUserName() {
            return CheckOutResponse(success: false, document: nil, tempFilePath: nil, error: DocumentError.documentAlreadyCheckedOut.localizedDescription)
        }
        
        try createTempDirectoryIfNeeded()
        
        let tempFileURL = tempDir.appendingPathComponent("\(document.id.uuidString)_\(document.fileName)")
        try fileManager.createDirectory(at: tempFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        if fileManager.fileExists(atPath: tempFileURL.path) {
            try fileManager.removeItem(at: tempFileURL)
        }
        
        try fileManager.copyItem(atPath: document.filePath, toPath: tempFileURL.path)
        
        var updatedDoc = document
        updatedDoc.status = .checkedOut
        updatedDoc.checkedOutBy = NSFullUserName()
        updatedDoc.checkedOutAt = Date()
        try storage.updateDocument(updatedDoc)
        
        return CheckOutResponse(
            success: true,
            document: updatedDoc,
            tempFilePath: tempFileURL.path,
            error: nil
        )
    }
    
    func checkIn(documentId: UUID, changeNotes: String? = nil) throws -> Document {
        guard let document = storage.getDocument(id: documentId) else {
            throw DocumentError.documentNotFound
        }
        
        guard document.isCheckedOut, document.checkedOutBy == NSFullUserName() else {
            throw DocumentError.documentNotCheckedOut
        }
        
        let tempFileURL = tempDir.appendingPathComponent("\(document.id.uuidString)_\(document.fileName)")
        
        guard fileManager.fileExists(atPath: tempFileURL.path) else {
            throw DocumentError.fileNotFound
        }
        
        let destURL = URL(fileURLWithPath: document.filePath)
        if fileManager.fileExists(atPath: destURL.path) {
            try fileManager.removeItem(at: destURL)
        }
        try fileManager.copyItem(at: tempFileURL, to: destURL)
        
        let attributes = try fileManager.attributesOfItem(atPath: destURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        _ = try storage.createVersion(
            documentId: documentId,
            sourcePath: destURL.path,
            changeNotes: changeNotes
        )
        
        guard var document = storage.getDocument(id: documentId) else {
            throw DocumentError.documentNotFound
        }
        document.status = .available
        document.checkedOutBy = nil
        document.checkedOutAt = nil
        document.fileSize = fileSize
        document.updatedAt = Date()
        try storage.updateDocument(document)
        
        try? fileManager.removeItem(at: tempFileURL)
        
        return document
    }
    
    func saveWorkingCopy(documentId: UUID) throws -> Document {
        guard let document = storage.getDocument(id: documentId) else {
            throw DocumentError.documentNotFound
        }
        
        guard document.isCheckedOut, document.checkedOutBy == NSFullUserName() else {
            throw DocumentError.documentNotCheckedOut
        }
        
        let tempFileURL = tempDir.appendingPathComponent("\(document.id.uuidString)_\(document.fileName)")
        
        guard fileManager.fileExists(atPath: tempFileURL.path) else {
            throw DocumentError.fileNotFound
        }
        
        let destURL = URL(fileURLWithPath: document.filePath)
        if fileManager.fileExists(atPath: destURL.path) {
            try fileManager.removeItem(at: destURL)
        }
        try fileManager.copyItem(at: tempFileURL, to: destURL)
        
        let attributes = try fileManager.attributesOfItem(atPath: destURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        _ = try storage.createVersion(
            documentId: documentId,
            sourcePath: destURL.path,
            changeNotes: "Working copy saved"
        )
        
        guard var document = storage.getDocument(id: documentId) else {
            throw DocumentError.documentNotFound
        }
        document.fileSize = fileSize
        document.updatedAt = Date()
        try storage.updateDocument(document)
        
        return document
    }
    
    func discardCheckOut(documentId: UUID) throws {
        guard let document = storage.getDocument(id: documentId) else {
            throw DocumentError.documentNotFound
        }
        
        guard document.isCheckedOut, document.checkedOutBy == NSFullUserName() else {
            throw DocumentError.documentNotCheckedOut
        }
        
        let tempFileURL = tempDir.appendingPathComponent("\(document.id.uuidString)_\(document.fileName)")
        try? fileManager.removeItem(at: tempFileURL)
        
        var updatedDoc = document
        updatedDoc.status = .available
        updatedDoc.checkedOutBy = nil
        updatedDoc.checkedOutAt = nil
        try storage.updateDocument(updatedDoc)
    }
    
    func lock(documentId: UUID) throws {
        guard var document = storage.getDocument(id: documentId) else {
            throw DocumentError.documentNotFound
        }
        
        if document.isLocked && document.checkedOutBy != NSFullUserName() {
            throw DocumentError.documentLockedByOther
        }
        
        document.status = .locked
        document.checkedOutBy = NSFullUserName()
        document.checkedOutAt = Date()
        try storage.updateDocument(document)
    }
    
    func unlock(documentId: UUID) throws {
        guard var document = storage.getDocument(id: documentId) else {
            throw DocumentError.documentNotFound
        }
        
        guard document.isLocked, document.checkedOutBy == NSFullUserName() else {
            throw DocumentError.unauthorized
        }
        
        document.status = .available
        document.checkedOutBy = nil
        document.checkedOutAt = nil
        try storage.updateDocument(document)
    }
    
    func canEdit(documentId: UUID) -> Bool {
        guard let document = storage.getDocument(id: documentId) else { return false }
        
        if document.isAvailable { return true }
        if document.isCheckedOut && document.checkedOutBy == NSFullUserName() { return true }
        return false
    }
    
    func getEditFileURL(documentId: UUID) throws -> URL {
        guard let document = storage.getDocument(id: documentId) else {
            throw DocumentError.documentNotFound
        }
        
        let tempFileURL = tempDir.appendingPathComponent("\(document.id.uuidString)_\(document.fileName)")
        
        if !fileManager.fileExists(atPath: tempFileURL.path) {
            if document.isCheckedOut && document.checkedOutBy == NSFullUserName() {
                let destURL = URL(fileURLWithPath: document.filePath)
                try fileManager.copyItem(at: destURL, to: tempFileURL)
            } else {
                _ = try checkOut(documentId: documentId)
            }
        }
        
        return tempFileURL
    }
    
    private func createTempDirectoryIfNeeded() throws {
        if !fileManager.fileExists(atPath: tempDir.path) {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }
    }
}
