import SwiftUI

struct GoogleDriveLinkImportView: View {
    @State private var urlString = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var progress: Double?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var documentVM: DocumentListViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if !GoogleDriveClient.shared.isAuthenticated {
                    notAuthenticatedView
                } else {
                    linkImportContent
                }
            }
            .frame(width: 400, height: 200)
            .navigationTitle("Import from Google Drive Link")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        Task { await importFromLink() }
                    }
                    .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || !GoogleDriveClient.shared.isAuthenticated)
                    .buttonStyle(.borderedProminent)
                }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var notAuthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Sign in to Google Drive to import from a link")
                .foregroundColor(.secondary)
            Button("Sign In") {
                Task {
                    do {
                        try await GoogleDriveClient.shared.authenticate()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var linkImportContent: some View {
        VStack(spacing: 16) {
            TextField("Paste Google Drive link", text: $urlString)
                .textFieldStyle(.roundedBorder)

            if isLoading {
                if let progress = progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 280)
                    Text("Downloading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ProgressView("Resolving link...")
                }
            }
        }
        .padding()
    }

    private func importFromLink() async {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Invalid URL"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let item = try await GoogleDriveClient.shared.resolveShareLink(url: url)

            if item.isFolder {
                errorMessage = "Folder links are not supported. Please use the browser import instead."
                isLoading = false
                return
            }

            let ext = fileExtension(for: item)
            let fileName = "\(item.name)\(ext)"
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PandyDoc/GoogleDrive", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let destURL = tempDir.appendingPathComponent(fileName)

            try await GoogleDriveClient.shared.downloadFile(fileID: item.id, to: destURL) { p in
                Task { @MainActor in
                    progress = p
                }
            }

            documentVM.importDocumentWithAccessCheck(fileURL: destURL, to: documentVM.currentFolder?.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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
