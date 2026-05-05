import Foundation
import AppKit
import SwiftUI

@MainActor
final class DocumentListViewModel: ObservableObject {
    @Published var documents: [Document] = []
    @Published var selectedDocument: Document?
    @Published var searchQuery = ""
    @Published var selectedTags: [String] = []
    @Published var filterStatus: DocumentStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showImportSheet = false
    @Published var showVersionHistory = false
    @Published var versions: [DocumentVersion] = []
    @Published var showCheckInSheet = false
    @Published var checkInNotes = ""
    
    private let storage: DocumentStorageProtocol
    private let checkInOut: CheckInOutProtocol
    private let editor: DocumentEditorService
    
    init(
        storage: DocumentStorageProtocol = DocumentStorage.shared,
        checkInOut: CheckInOutProtocol = CheckInOutService.shared,
        editor: DocumentEditorService = DocumentEditorService.shared
    ) {
        self.storage = storage
        self.checkInOut = checkInOut
        self.editor = editor
        
        setupNotifications()
        refreshDocuments()
    }
    
    func refreshDocuments() {
        documents = storage.getAllDocuments()
        applyFilters()
    }
    
    func searchDocuments() {
        if searchQuery.isEmpty && selectedTags.isEmpty {
            documents = storage.getAllDocuments()
        } else {
            documents = storage.searchDocuments(query: searchQuery, tags: selectedTags)
        }
        applyStatusFilter()
    }
    
    func importDocument(fileURL: URL) {
        do {
            let fileName = fileURL.lastPathComponent
            let docName = (fileName as NSString).deletingPathExtension
            
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PandyDoc/Import", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let destURL = tempDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: fileURL, to: destURL)
            
            let attributes = try FileManager.default.attributesOfItem(atPath: destURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            let document = Document.createNew(
                name: docName,
                fileName: fileName,
                filePath: destURL.path,
                fileSize: fileSize
            )
            
            try storage.saveDocument(document)
            _ = try storage.createVersion(
                documentId: document.id,
                sourcePath: destURL.path,
                changeNotes: "Initial import"
            )
            
            refreshDocuments()
        } catch {
            errorMessage = "Failed to import document: \(error.localizedDescription)"
        }
    }
    
    func checkOut(document: Document) {
        do {
            let response = try checkInOut.checkOut(documentId: document.id)
            if response.success {
                refreshDocuments()
                if let tempPath = response.tempFilePath {
                    NSWorkspace.shared.open(URL(fileURLWithPath: tempPath))
                }
            } else {
                errorMessage = response.error
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func checkIn(document: Document) {
        selectedDocument = document
        checkInNotes = ""
        showCheckInSheet = true
    }
    
    func performCheckIn(document: Document) {
        do {
            _ = try checkInOut.checkIn(documentId: document.id, changeNotes: checkInNotes)
            showCheckInSheet = false
            checkInNotes = ""
            refreshDocuments()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func discardCheckOut(document: Document) {
        do {
            try checkInOut.discardCheckOut(documentId: document.id)
            refreshDocuments()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func lockDocument(document: Document) {
        do {
            try checkInOut.lock(documentId: document.id)
            refreshDocuments()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func unlockDocument(document: Document) {
        do {
            try checkInOut.unlock(documentId: document.id)
            refreshDocuments()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func openDocument(document: Document) {
        do {
            try editor.openWithApp(documentId: document.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func showVersions(for document: Document) {
        selectedDocument = document
        versions = storage.getVersions(documentId: document.id)
        showVersionHistory = true
    }
    
    func restoreVersion(documentId: UUID, versionNumber: Int) {
        do {
            _ = try storage.restoreVersion(documentId: documentId, versionNumber: versionNumber)
            versions = storage.getVersions(documentId: documentId)
            refreshDocuments()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteDocument(document: Document) {
        do {
            try storage.deleteDocument(id: document.id)
            if selectedDocument?.id == document.id {
                selectedDocument = nil
            }
            refreshDocuments()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func getStatusIcon(_ status: DocumentStatus) -> String {
        switch status {
        case .available: return "checkmark.circle.fill"
        case .checkedOut: return "pencil.circle.fill"
        case .locked: return "lock.fill"
        }
    }
    
    func getStatusColor(_ status: DocumentStatus) -> Color {
        switch status {
        case .available: return .green
        case .checkedOut: return .blue
        case .locked: return .red
        }
    }
    
    private func applyFilters() {
        applyStatusFilter()
    }
    
    private func applyStatusFilter() {
        guard let filter = filterStatus else { return }
        documents = documents.filter { $0.status == filter }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .documentReceived,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshDocuments()
        }
        
        NotificationCenter.default.addObserver(
            forName: .documentCheckedIn,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshDocuments()
        }
    }
}
