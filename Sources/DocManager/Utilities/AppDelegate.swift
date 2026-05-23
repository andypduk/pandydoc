import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupAppIcon()
        setupNotifications()
        FolderAccessManager.shared.resolveAllBookmarks()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func setupAppIcon() {
        if let iconURL = Bundle.main.url(forResource: "PandaIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        FolderAccessManager.shared.releaseAllAccess()
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleDocumentOpen(url: url)
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleImportDocument),
            name: .importDocument,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleImportFolder),
            name: .importFolder,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCheckInDocument),
            name: .checkInDocument,
            object: nil
        )
    }

    @objc private func handleImportFolder(_ notification: Notification) {
        guard let url = notification.userInfo?["url"] as? URL else { return }
        _ = url.startAccessingSecurityScopedResource()
        let folderURL = url
        try? FolderAccessManager.shared.grantAccess(to: folderURL)
        try? DocumentStorage.shared.importFolderIfNotExists(url: folderURL)
        url.stopAccessingSecurityScopedResource()
        FolderAccessManager.shared.resolveAllBookmarks()
    }
    
    @objc private func handleImportDocument() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.allowedContentTypes = [.pdf, .data, .text, .rtf]

        openPanel.begin { response in
            if response == .OK {
                for url in openPanel.urls {
                    _ = url.startAccessingSecurityScopedResource()
                    let folderURL = url.deletingLastPathComponent()
                    try? FolderAccessManager.shared.grantAccess(to: folderURL)
                    try? DocumentStorage.shared.importDocumentIfNotExists(url: url)
                    url.stopAccessingSecurityScopedResource()
                }
                FolderAccessManager.shared.resolveAllBookmarks()
            }
        }
    }
    
    @objc private func handleCheckInDocument() {
        NotificationCenter.default.post(name: .documentCheckedIn, object: nil)
    }
    
    private func handleDocumentOpen(url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            try DocumentStorage.shared.importDocumentIfNotExists(url: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to import document"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

extension DocumentStorage {
    func importDocumentIfNotExists(url: URL) throws {
        let fileName = url.lastPathComponent
        let docName = (fileName as NSString).deletingPathExtension
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PandyDoc/Import", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let destURL = tempDir.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.copyItem(at: url, to: destURL)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: destURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        let document = Document.createNew(
            name: docName,
            fileName: fileName,
            filePath: destURL.path,
            fileSize: fileSize
        )
        
        try saveDocument(document)
        _ = try createVersion(
            documentId: document.id,
            sourcePath: destURL.path,
            changeNotes: "Initial import"
        )
        
        NotificationCenter.default.post(
            name: .documentReceived,
            object: nil,
            userInfo: ["documentId": document.id, "documentName": document.name]
        )
    }

    func importFolderIfNotExists(url: URL) throws {
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw NSError(domain: "PandyDoc", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read folder contents"])
        }

        let items = enumerator.allObjects.compactMap { $0 as? URL }
        for fileURL in items {
            let attributes = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if attributes.isDirectory != true {
                try importDocumentIfNotExists(url: fileURL)
            }
        }
    }
}
