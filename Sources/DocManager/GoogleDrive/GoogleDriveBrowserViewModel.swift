import Foundation
import SwiftUI

@MainActor
final class GoogleDriveBrowserViewModel: ObservableObject {
    @Published var items: [GDriveItem] = []
    @Published var selectedItems: Set<String> = []
    @Published var currentFolderID: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var downloadProgress: Double?
    @Published var importCurrentFile = 0
    @Published var importTotalFiles = 0

    private var folderPath: [GDriveItem] = []
    private let documentVM: DocumentListViewModel

    init(documentVM: DocumentListViewModel) {
        self.documentVM = documentVM
    }

    func loadItems() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let fileList = try await GoogleDriveClient.shared.listFiles(parentID: currentFolderID)
                items = fileList.items.sorted { a, b in
                    if a.isFolder != b.isFolder { return a.isFolder }
                    return a.name.localizedStandardCompare(b.name) == .orderedAscending
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func navigateTo(folder: GDriveItem) {
        folderPath.append(folder)
        currentFolderID = folder.id
        loadItems()
    }

    func navigateUp() {
        if folderPath.isEmpty {
            currentFolderID = nil
        } else {
            _ = folderPath.popLast()
            currentFolderID = folderPath.last?.id
        }
        loadItems()
    }

    func toggleSelection(_ item: GDriveItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    func importSelected() {
        guard !selectedItems.isEmpty else { return }
        Task {
            await performImport()
        }
    }

    private func performImport() async {
        let selected = items.filter { selectedItems.contains($0.id) }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PandyDoc/GoogleDrive", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var fileCount = 0
        for item in selected {
            if item.isFolder {
                fileCount += 1
            } else {
                fileCount += 1
            }
        }

        let totalItems = fileCount
        await MainActor.run {
            documentVM.importTotalFiles = totalItems
            documentVM.importCurrentFile = 0
            documentVM.importProgress = totalItems > 0 ? 0 : nil
        }

        var completedCount = 0
        for item in selected {
            do {
                if item.isFolder {
                    let folderTempDir = tempDir.appendingPathComponent(item.name, isDirectory: true)
                    try FileManager.default.createDirectory(at: folderTempDir, withIntermediateDirectories: true)
                    try await downloadFolderContents(folderID: item.id, to: folderTempDir, completedCount: &completedCount, total: totalItems)
                } else {
                    let ext = fileExtension(for: item)
                    let fileName = "\(item.name)\(ext)"
                    let destURL = tempDir.appendingPathComponent(fileName)
                    try await GoogleDriveClient.shared.downloadFile(fileID: item.id, to: destURL) { _ in }
                    documentVM.importDocumentWithAccessCheck(fileURL: destURL, to: documentVM.currentFolder?.id)
                    completedCount += 1
                }
                await updateProgress(completed: completedCount, total: totalItems)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to import \(item.name): \(error.localizedDescription)"
                }
            }
        }

        await MainActor.run {
            documentVM.importProgress = nil
            selectedItems.removeAll()
        }
    }

    private func downloadFolderContents(folderID: String, to directory: URL, completedCount: inout Int, total: Int) async throws {
        let fileList = try await GoogleDriveClient.shared.listFiles(parentID: folderID)
        for item in fileList.items {
            if item.isFolder {
                let subDir = directory.appendingPathComponent(item.name, isDirectory: true)
                try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
                try await downloadFolderContents(folderID: item.id, to: subDir, completedCount: &completedCount, total: total)
            } else {
                let ext = fileExtension(for: item)
                let fileName = "\(item.name)\(ext)"
                let destURL = directory.appendingPathComponent(fileName)
                try await GoogleDriveClient.shared.downloadFile(fileID: item.id, to: destURL) { _ in }
                documentVM.importDocumentWithAccessCheck(fileURL: destURL, to: documentVM.currentFolder?.id)
                completedCount += 1
                await updateProgress(completed: completedCount, total: total)
            }
        }
    }

    private func updateProgress(completed: Int, total: Int) async {
        await MainActor.run {
            documentVM.importCurrentFile = completed
            documentVM.importProgress = total > 0 ? Double(completed) / Double(total) : 1.0
        }
    }

    private func fileExtension(for item: GDriveItem) -> String {
        let mimeTypeToExt: [String: String] = [
            "application/pdf": ".pdf",
            "image/jpeg": ".jpg",
            "image/png": ".png",
            "application/msword": ".doc",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document": ".docx",
            "application/vnd.google-apps.document": ".docx",
            "application/vnd.google-apps.spreadsheet": ".xlsx",
            "application/vnd.google-apps.presentation": ".pptx",
        ]
        if let ext = mimeTypeToExt[item.mimeType] {
            return ext
        }
        if let nameExt = (item.name as NSString).pathExtension, !nameExt.isEmpty {
            return ".\(nameExt)"
        }
        return ""
    }
}
