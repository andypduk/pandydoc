import Foundation
import AppKit

protocol DocumentEditorProtocol {
    func openDocument(documentId: UUID) throws -> OpenDocumentResult
    func saveChanges(documentId: UUID) throws
    func saveWorkingCopy(documentId: UUID) throws -> Document
    func closeDocument(documentId: UUID)
    func openWithApp(documentId: UUID, appURL: URL?) throws
}

struct OpenDocumentResult {
    let document: Document
    let fileURL: URL
    let isExternalEdit: Bool
}

final class DocumentEditorService: DocumentEditorProtocol, FileWatcherDelegate {
    static let shared = DocumentEditorService()
    
    private let checkInOut: CheckInOutProtocol
    private let storage: DocumentStorageProtocol
    private let fileWatcher = FileWatcher()
    private var openDocuments: [UUID: OpenDocumentInfo] = [:]
    private let notificationCenter = NotificationCenter.default
    
    struct OpenDocumentInfo {
        let documentId: UUID
        let tempURL: URL
        let process: Process?
        let openedAt: Date
    }
    
    private init(
        checkInOut: CheckInOutProtocol = CheckInOutService.shared,
        storage: DocumentStorageProtocol = DocumentStorage.shared
    ) {
        self.checkInOut = checkInOut
        self.storage = storage
        fileWatcher.delegate = self
    }
    
    func openDocument(documentId: UUID) throws -> OpenDocumentResult {
        guard let document = storage.getDocument(id: documentId) else {
            throw DocumentError.documentNotFound
        }
        
        let fileURL: URL
        let isExternalEdit: Bool
        
        if document.isCheckedOut && document.checkedOutBy == NSFullUserName() {
            let tempURL = URL(fileURLWithPath: document.filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("\(document.id.uuidString)_\(document.fileName)")
            fileURL = tempURL
            isExternalEdit = true
        } else {
            let response = try checkInOut.checkOut(documentId: documentId)
            guard let tempPath = response.tempFilePath,
                  let _ = response.document else {
                throw DocumentError.checkoutFailed(response.error ?? "Unknown error")
            }
            fileURL = URL(fileURLWithPath: tempPath)
            isExternalEdit = true
        }
        
        fileWatcher.startWatching(documentId: documentId, filePath: fileURL.path)
        
        let info = OpenDocumentInfo(
            documentId: documentId,
            tempURL: fileURL,
            process: nil,
            openedAt: Date()
        )
        openDocuments[documentId] = info
        
        return OpenDocumentResult(
            document: document,
            fileURL: fileURL,
            isExternalEdit: isExternalEdit
        )
    }
    
    func saveChanges(documentId: UUID) throws {
        guard openDocuments[documentId] != nil else {
            return
        }
        try performCheckIn(documentId: documentId, changeNotes: nil)
    }
    
    func saveWorkingCopy(documentId: UUID) throws -> Document {
        guard openDocuments[documentId] != nil else {
            throw DocumentError.documentNotFound
        }
        return try checkInOut.saveWorkingCopy(documentId: documentId)
    }
    
    func closeDocument(documentId: UUID) {
        fileWatcher.stopWatching(filePath: openDocuments[documentId]?.tempURL.path ?? "")
        openDocuments.removeValue(forKey: documentId)
    }
    
    func openWithApp(documentId: UUID, appURL: URL? = nil) throws {
        let result = try openDocument(documentId: documentId)
        
        var targetAppURL: URL? = appURL
        if targetAppURL == nil {
            guard let document = storage.getDocument(id: documentId) else {
                throw DocumentError.documentNotFound
            }
            targetAppURL = findDefaultApp(for: document.documentType)
        }
        
        if let appURL = targetAppURL {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open([result.fileURL], withApplicationAt: appURL, configuration: config) { _, error in
                if let error = error {
                    print("Failed to open document: \(error.localizedDescription)")
                }
            }
        } else {
            NSWorkspace.shared.open(result.fileURL)
        }
    }
    
    func fileDidChange(at path: String) {
        let matchingDoc = openDocuments.first { $0.value.tempURL.path == path }
        guard let documentId = matchingDoc?.key else { return }
        
        do {
            _ = try checkInOut.saveWorkingCopy(documentId: documentId)
        } catch {
            print("Failed to save working copy: \(error)")
        }
        
        notificationCenter.post(
            name: .documentExternallyModified,
            object: nil,
            userInfo: ["documentId": documentId, "filePath": path]
        )
    }
    
    func fileWasDeleted(at path: String) {
        let matchingDoc = openDocuments.first { $0.value.tempURL.path == path }
        guard let documentId = matchingDoc?.key else { return }
        
        notificationCenter.post(
            name: .documentExternallyDeleted,
            object: nil,
            userInfo: ["documentId": documentId]
        )
        
        openDocuments.removeValue(forKey: documentId)
    }
    
    private func performCheckIn(documentId: UUID, changeNotes: String?) throws {
        guard let info = openDocuments[documentId] else { return }
        
        _ = try checkInOut.checkIn(documentId: documentId, changeNotes: changeNotes)
        
        fileWatcher.stopWatching(filePath: info.tempURL.path)
        openDocuments.removeValue(forKey: documentId)
        
        notificationCenter.post(
            name: .documentCheckedIn,
            object: nil,
            userInfo: ["documentId": documentId]
        )
    }
    
    private func findDefaultApp(for documentType: DocumentType) -> URL? {
        if let appName = documentType.defaultApp {
            let workspace = NSWorkspace.shared
            for app in workspace.runningApplications {
                if app.localizedName?.contains(appName) == true,
                   let bundleURL = app.bundleURL {
                    return bundleURL
                }
            }
            
            if let url = workspace.urlForApplication(toOpen: URL(fileURLWithPath: "/tmp/dummy.\(documentType.rawValue)")) {
                return url
            }
        }
        
        return nil
    }
    
    func autoSaveCheck() {
        for (_, info) in openDocuments {
            let fileURL = info.tempURL
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    let modifiedDate = attributes[.modificationDate] as? Date ?? Date()
                    
                    if modifiedDate > info.openedAt {
                        fileDidChange(at: fileURL.path)
                    }
                } catch {
                    print("Auto-save check failed: \(error)")
                }
            }
        }
    }
}

extension Notification.Name {
    static let documentExternallyModified = Notification.Name("documentExternallyModified")
    static let documentExternallyDeleted = Notification.Name("documentExternallyDeleted")
    static let documentCheckedIn = Notification.Name("documentCheckedIn")
    static let documentReceived = Notification.Name("documentReceived")
    static let documentVersionCreated = Notification.Name("documentVersionCreated")
}
