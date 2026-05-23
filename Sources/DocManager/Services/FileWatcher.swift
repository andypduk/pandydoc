import Foundation

protocol FileWatcherDelegate: AnyObject {
    func fileDidChange(at path: String)
    func fileWasDeleted(at path: String)
}

final class FileWatcher {
    weak var delegate: FileWatcherDelegate?
    
    private var fileDescriptors: [String: Int32] = [:]
    private let queue = DispatchQueue(label: "com.pandydoc.filewatcher", attributes: .concurrent)
    
    private var monitorTimer: Timer?
    private var watchedFiles: [String: FileMonitorInfo] = [:]
    
    struct FileMonitorInfo {
        let path: String
        var lastModified: Date
        var lastSize: Int64
        let documentId: UUID
    }
    
    func startWatching(documentId: UUID, filePath: String) {
        let info = FileMonitorInfo(
            path: filePath,
            lastModified: fileModificationDate(filePath) ?? Date(),
            lastSize: fileSize(filePath) ?? 0,
            documentId: documentId
        )
        watchedFiles[filePath] = info
        
        if monitorTimer == nil {
            DispatchQueue.main.async {
                self.monitorTimer = Timer.scheduledTimer(
                    withTimeInterval: 1.0,
                    repeats: true
                ) { [weak self] _ in
                    self?.checkForChanges()
                }
            }
        }
    }
    
    func stopWatching(filePath: String) {
        watchedFiles.removeValue(forKey: filePath)
    }
    
    func stopAll() {
        watchedFiles.removeAll()
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    private func checkForChanges() {
        for (path, info) in watchedFiles {
            let currentModified = fileModificationDate(path) ?? Date()
            let currentSize = fileSize(path) ?? 0
            
            if currentModified > info.lastModified || currentSize != info.lastSize {
                delegate?.fileDidChange(at: path)
                
                var updatedInfo = info
                updatedInfo.lastModified = currentModified
                updatedInfo.lastSize = currentSize
                watchedFiles[path] = updatedInfo
            }
            
            if !FileManager.default.fileExists(atPath: path) {
                delegate?.fileWasDeleted(at: path)
                watchedFiles.removeValue(forKey: path)
            }
        }
    }
    
    private func fileModificationDate(_ path: String) -> Date? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }
    
    private func fileSize(_ path: String) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
}
