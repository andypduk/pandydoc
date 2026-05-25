import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct VersionHistoryView: View {
    @ObservedObject var viewModel: DocumentListViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(viewModel.versions) { version in
                VersionRowView(version: version, viewModel: viewModel)
            }
            .listStyle(.inset)
            .navigationTitle("Version History")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 540, height: 400)
    }
}

struct VersionRowView: View {
    let version: DocumentVersion
    @ObservedObject var viewModel: DocumentListViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            versionNumberBadge
            
            VStack(alignment: .leading, spacing: 4) {
                Text(version.fileName)
                    .font(.body)
                
                HStack(spacing: 12) {
                    Text(version.createdBy)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatDate(version.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatFileSize(version.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let notes = version.changeNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Button(action: {
                    saveVersionAs(version)
                }) {
                    Label("Save As...", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    viewModel.restoreVersion(
                        documentId: version.documentId,
                        versionNumber: version.versionNumber
                    )
                }) {
                    Label("Restore", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var versionNumberBadge: some View {
        Text("v\(version.versionNumber)")
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.15))
            .cornerRadius(12)
    }

    private func saveVersionAs(_ version: DocumentVersion) {
        let savePanel = NSSavePanel()
        savePanel.title = "Save Version As"
        savePanel.nameFieldStringValue = version.fileName
        savePanel.canCreateDirectories = true

        if let utType = UTType(filenameExtension: (version.fileName as NSString).pathExtension) {
            savePanel.allowedContentTypes = [utType]
        }

        savePanel.begin { response in
            guard response == .OK, let destURL = savePanel.url else { return }
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                let sourceURL: URL
                if let filePath = version.filePath {
                    sourceURL = URL(fileURLWithPath: filePath)
                } else {
                    sourceURL = try self.viewModel.decompressVersionIfNeeded(documentId: version.documentId, versionNumber: version.versionNumber)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
            } catch {
                DispatchQueue.main.async {
                    viewModel.errorMessage = "Failed to save version: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
