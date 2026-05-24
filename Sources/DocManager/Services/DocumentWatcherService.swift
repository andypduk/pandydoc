import Foundation
import AppKit

final class DocumentWatcherService {
    static let shared = DocumentWatcherService()
    
    private let fileManager = FileManager.default
    private let checkInOut: CheckInOutProtocol
    private let storage: DocumentStorageProtocol
    
    private var watchers: [UUID: FileHandle] = [:]
    private var queue = DispatchQueue(label: "com.pandydoc.watcher", attributes: .concurrent)
    
    private init(
        checkInOut: CheckInOutProtocol = CheckInOutService.shared,
        storage: DocumentStorageProtocol = DocumentStorage.shared
    ) {
        self.checkInOut = checkInOut
        self.storage = storage
    }
    
    func startWatching(document: Document) {
        queue.async {
            self.stopWatching(documentId: document.id)
            
            let fileURL = URL(fileURLWithPath: document.filePath)
            guard self.fileManager.fileExists(atPath: fileURL.path) else { return }
            
            do {
                let fileHandle = try FileHandle(forReadingFrom: fileURL)
                self.watchers[document.id] = fileHandle
                
                self.setupKQueueWatch(for: document, fileHandle: fileHandle)
            } catch {
                print("Failed to watch document \(document.name): \(error)")
            }
        }
    }
    
    func stopWatching(documentId: UUID) {
        queue.async {
            try? self.watchers[documentId]?.close()
            self.watchers.removeValue(forKey: documentId)
        }
    }
    
    func setupAutoCheckIn(documentId: UUID) {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            if let document = self.storage.getDocument(id: documentId) {
                if document.isCheckedOut && document.checkedOutBy == NSFullUserName() {
                    _ = try? self.checkInOut.checkIn(documentId: documentId, changeNotes: "Auto check-in on app close")
                }
            }
        }
    }
    
    private func setupKQueueWatch(for document: Document, fileHandle: FileHandle) {
        #if os(macOS)
        let kq = kqueue()
        guard kq >= 0 else { return }
        
        var event = kevent()
        event.ident = UInt(fileHandle.fileDescriptor)
        event.filter = Int16(EVFILT_VNODE)
        event.flags = UInt16(EV_ADD | EV_ENABLE | EV_ONESHOT)
        event.fflags = UInt32(NOTE_WRITE | NOTE_DELETE | NOTE_RENAME)
        
        kevent(kq, &event, 1, nil, 0, nil)
        #endif
    }
    
    func watchDirectoryForChanges() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let incomingURL = appSupport
            .appendingPathComponent("PandyDoc/Incoming", isDirectory: true)
        
        if !fileManager.fileExists(atPath: incomingURL.path) {
            try? fileManager.createDirectory(at: incomingURL, withIntermediateDirectories: true)
        }
        
        startDirectoryWatcher(url: incomingURL)
    }
    
    private func startDirectoryWatcher(url: URL) {
        DispatchQueue.global(qos: .background).async {
            var previousFiles: Set<String> = []
            
            while true {
                do {
                    let files = Set(try self.fileManager.contentsOfDirectory(atPath: url.path))
                    
                    let newFiles = files.subtracting(previousFiles)
                    
                    for file in newFiles {
                        let filePath = url.appendingPathComponent(file).path
                        self.processIncomingFile(filePath: filePath)
                    }
                    
                    previousFiles = files
                } catch {
                    print("Directory watcher error: \(error)")
                }
                
                Thread.sleep(forTimeInterval: 2)
            }
        }
    }
    
    private func processIncomingFile(filePath: String) {
        let fileName = (filePath as NSString).lastPathComponent
        
        DispatchQueue.main.async {
            do {
                let inboxFolderID = self.getInboxFolderID()
                let document = try self.storage.storeReceivedPDF(
                    sourcePath: filePath,
                    fileName: fileName,
                    parentID: inboxFolderID,
                    tags: []
                )
                
                try? self.fileManager.removeItem(atPath: filePath)
                
                NotificationCenter.default.post(
                    name: .documentReceived,
                    object: nil,
                    userInfo: ["documentId": document.id, "documentName": document.name]
                )
            } catch {
                print("Failed to process incoming file: \(error)")
            }
        }
    }
    
    private func getInboxFolderID() -> UUID? {
        let allFolders = self.storage.getAllFolders()
        return allFolders.first { $0.name == "Inbox" }?.id
    }
}
