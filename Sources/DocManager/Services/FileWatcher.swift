import Foundation

protocol FileWatcherDelegate: AnyObject {
    func fileDidChange(at path: String)
    func fileWasDeleted(at path: String)
}

final class FileWatcher {
    weak var delegate: FileWatcherDelegate?
    
    private let queue = DispatchQueue(label: "com.pandydoc.filewatcher", attributes: .concurrent)
    private var sources: [String: DispatchSourceFileSystemObject] = [:]
    private var fileHandles: [String: Int32] = [:]
    private var documentIds: [String: UUID] = [:]
    private var initialSizes: [String: Int64] = [:]
    private var pendingDeleteTimers: [String: DispatchWorkItem] = [:]
    
    func startWatching(documentId: UUID, filePath: String) {
        queue.async {
            self.stopWatching(filePath: filePath)
            let initialSize = self.fileSize(filePath) ?? 0
            self.initialSizes[filePath] = initialSize
            self.setupSource(documentId: documentId, filePath: filePath)
        }
    }
    
    private func fileSize(_ path: String) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
    
    private func setupSource(documentId: UUID, filePath: String) {
        let fd = open(filePath, O_EVTONLY)
        guard fd >= 0 else {
            print("FileWatcher: Failed to open file descriptor for \(filePath)")
            return
        }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: self.queue
        )
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.handleEvent(documentId: documentId, filePath: filePath, fd: fd, source: source)
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        source.resume()
        self.sources[filePath] = source
        self.fileHandles[filePath] = fd
        self.documentIds[filePath] = documentId
    }
    
    private func handleEvent(documentId: UUID, filePath: String, fd: Int32, source: DispatchSourceFileSystemObject) {
        let flags = source.data
        
        if flags.contains(.delete) || flags.contains(.rename) {
            if FileManager.default.fileExists(atPath: filePath) {
                let currentSize = self.fileSize(filePath) ?? 0
                let initialSize = self.initialSizes[filePath] ?? 0
                
                if currentSize != initialSize {
                    self.initialSizes[filePath] = currentSize
                    self.delegate?.fileDidChange(at: filePath)
                }
                
                self.reopenSource(documentId: documentId, filePath: filePath, currentFd: fd, currentSource: source)
            } else {
                self.pendingDeleteTimers[filePath]?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    if !FileManager.default.fileExists(atPath: filePath) {
                        self.delegate?.fileWasDeleted(at: filePath)
                        self.stopWatching(filePath: filePath)
                    }
                    self.pendingDeleteTimers.removeValue(forKey: filePath)
                }
                pendingDeleteTimers[filePath] = work
                queue.asyncAfter(deadline: .now() + 0.5, execute: work)
            }
            return
        }
        
        if flags.contains(.write) || flags.contains(.attrib) {
            if FileManager.default.fileExists(atPath: filePath) {
                let currentSize = self.fileSize(filePath) ?? 0
                let initialSize = self.initialSizes[filePath] ?? 0
                
                if currentSize != initialSize {
                    self.initialSizes[filePath] = currentSize
                    self.delegate?.fileDidChange(at: filePath)
                }
                
                self.reopenSource(documentId: documentId, filePath: filePath, currentFd: fd, currentSource: source)
            }
        }
    }
    
    private func reopenSource(documentId: UUID, filePath: String, currentFd: Int32, currentSource: DispatchSourceFileSystemObject) {
        currentSource.cancel()
        self.sources.removeValue(forKey: filePath)
        self.fileHandles.removeValue(forKey: filePath)
        
        let fd = open(filePath, O_EVTONLY)
        guard fd >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: self.queue
        )
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.handleEvent(documentId: documentId, filePath: filePath, fd: fd, source: source)
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        source.resume()
        self.sources[filePath] = source
        self.fileHandles[filePath] = fd
        self.documentIds[filePath] = documentId
    }
    
    func stopWatching(filePath: String) {
        queue.async {
            self.pendingDeleteTimers[filePath]?.cancel()
            self.pendingDeleteTimers.removeValue(forKey: filePath)
            self.sources[filePath]?.cancel()
            self.sources.removeValue(forKey: filePath)
            self.fileHandles.removeValue(forKey: filePath)
            self.documentIds.removeValue(forKey: filePath)
            self.initialSizes.removeValue(forKey: filePath)
        }
    }
    
    func stopAll() {
        queue.sync {
            for (_, timer) in self.pendingDeleteTimers {
                timer.cancel()
            }
            self.pendingDeleteTimers.removeAll()
            for (_, source) in self.sources {
                source.cancel()
            }
            self.sources.removeAll()
            self.fileHandles.removeAll()
            self.documentIds.removeAll()
            self.initialSizes.removeAll()
        }
    }
}
