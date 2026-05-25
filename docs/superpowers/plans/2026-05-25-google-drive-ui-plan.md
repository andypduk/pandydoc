# Google Drive Import — UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build browse-in-app UI and share link import UI for Google Drive, integrated into the existing Import menu.

**Architecture:** Three new SwiftUI files under `Sources/DocManager/GoogleDrive/` plus modifications to `ContentView.swift` for menu integration. ViewModel bridges to existing import pipeline.

**Tech Stack:** SwiftUI, existing GoogleDriveClient, existing DocumentListViewModel import methods

---

## File Structure

**Create:**
- `Sources/DocManager/GoogleDrive/GoogleDriveBrowserViewModel.swift`
- `Sources/DocManager/GoogleDrive/GoogleDriveBrowserView.swift`
- `Sources/DocManager/GoogleDrive/GoogleDriveLinkImportView.swift`

**Modify:**
- `Sources/DocManager/Views/ContentView.swift` — convert Import button to Menu, add sheet bindings

---

### Task 1: Create GoogleDriveBrowserViewModel.swift

**Files:**
- Create: `Sources/DocManager/GoogleDrive/GoogleDriveBrowserViewModel.swift`

- [ ] **Step 1: Write the view model**

```swift
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
        var folderCount = 0
        for item in selected {
            if item.isFolder {
                folderCount += 1
            } else {
                fileCount += 1
            }
        }

        let totalItems = fileCount + folderCount
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
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/GoogleDrive/GoogleDriveBrowserViewModel.swift
git commit -m "feat: add Google Drive browser view model"
```

---

### Task 2: Create GoogleDriveBrowserView.swift

**Files:**
- Create: `Sources/DocManager/GoogleDrive/GoogleDriveBrowserView.swift`

- [ ] **Step 1: Write the browser view**

```swift
import SwiftUI

struct GoogleDriveBrowserView: View {
    @StateObject private var viewModel: GoogleDriveBrowserViewModel
    @Environment(\.dismiss) private var dismiss

    init(documentVM: DocumentListViewModel) {
        _viewModel = StateObject(wrappedValue: GoogleDriveBrowserViewModel(documentVM: documentVM))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !GoogleDriveClient.shared.isAuthenticated {
                    notAuthenticatedView
                } else {
                    browserContent
                }
            }
            .frame(width: 500, height: 450)
            .navigationTitle("Import from Google Drive")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if GoogleDriveClient.shared.isAuthenticated {
                        Button("Import \(viewModel.selectedItems.count) item\(viewModel.selectedItems.count == 1 ? "" : "s")") {
                            viewModel.importSelected()
                        }
                        .disabled(viewModel.selectedItems.isEmpty || viewModel.isLoading || viewModel.downloadProgress != nil)
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Sign In") {
                            Task { try? await viewModel.documentVM }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                viewModel.loadItems()
            }
        }
    }

    private var notAuthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Sign in to Google Drive to browse and import files")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Sign In") {
                Task {
                    do {
                        try await GoogleDriveClient.shared.authenticate()
                        viewModel.loadItems()
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var browserContent: some View {
        VStack(spacing: 0) {
            if !viewModel.folderPath.isEmpty {
                breadcrumbBar
                Divider()
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.items.isEmpty {
                ContentUnavailableView("No items", systemImage: "folder", description: Text("This folder is empty"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                fileList
            }

            if viewModel.downloadProgress != nil {
                Divider()
                downloadProgressOverlay
            }
        }
    }

    private var breadcrumbBar: some View {
        HStack {
            Button("Root") {
                viewModel.navigateUp()
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            ForEach(Array(viewModel.folderPath.enumerated()), id: \.element.id) { index, folder in
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button(folder.name) {
                    while viewModel.folderPath.count > index + 1 {
                        viewModel.navigateUp()
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var fileList: some View {
        List {
            ForEach(viewModel.items) { item in
                HStack(spacing: 8) {
                    Toggle("", isOn: Binding(
                        get: { viewModel.selectedItems.contains(item.id) },
                        set: { _ in viewModel.toggleSelection(item) }
                    ))
                    .labelsHidden()
                    .disabled(item.isFolder && item.mimeType == "application/vnd.google-apps.folder")

                    Image(systemName: item.isFolder ? "folder.fill" : fileIcon(for: item))
                        .foregroundColor(item.isFolder ? .accentColor : .secondary)
                        .frame(width: 20)

                    Text(item.name)
                        .lineLimit(1)

                    Spacer()

                    if let size = item.size, !item.isFolder {
                        Text(sizeFormatted(size))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if item.isFolder {
                        viewModel.navigateTo(folder: item)
                    } else {
                        viewModel.toggleSelection(item)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private var downloadProgressOverlay: some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.documentVM.importProgress ?? 0)
                .progressViewStyle(.linear)
                .frame(width: 280)
            Text("Importing \(viewModel.documentVM.importCurrentFile) of \(viewModel.documentVM.importTotalFiles) files (\(Int((viewModel.documentVM.importProgress ?? 0) * 100))%)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
    }

    private func fileIcon(for item: GDriveItem) -> String {
        if item.mimeType.contains("pdf") { return "doc.richtext.fill" }
        if item.mimeType.contains("image") { return "photo.fill" }
        if item.mimeType.contains("word") || item.mimeType.contains("document") { return "doc.text.fill" }
        if item.mimeType.contains("spreadsheet") { return "tablecells.fill" }
        if item.mimeType.contains("presentation") { return "play.rectangle.fill" }
        return "doc.fill"
    }

    private func sizeFormatted(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/GoogleDrive/GoogleDriveBrowserView.swift
git commit -m "feat: add Google Drive browser view"
```

---

### Task 3: Create GoogleDriveLinkImportView.swift

**Files:**
- Create: `Sources/DocManager/GoogleDrive/GoogleDriveLinkImportView.swift`

- [ ] **Step 1: Write the link import view**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/GoogleDrive/GoogleDriveLinkImportView.swift
git commit -m "feat: add Google Drive link import view"
```

---

### Task 4: Integrate into ContentView

**Files:**
- Modify: `Sources/DocManager/Views/ContentView.swift:179-184`

- [ ] **Step 1: Add state bindings**

Add these `@State` properties near the existing `@State private var showImportSheet = false` (around line 13):

```swift
@State private var showGoogleDriveBrowser = false
@State private var showGoogleDriveLinkImport = false
```

- [ ] **Step 2: Replace Import button with Menu**

Replace the Import toolbar item (lines 179-184) with:

```swift
ToolbarItem(placement: .primaryAction) {
    Menu {
        Button(action: { showImportSheet = true }) {
            Label("Import from Computer...", systemImage: "macwindow")
        }
        Button(action: { showGoogleDriveBrowser = true }) {
            Label("Import from Google Drive...", systemImage: "cloud.fill")
        }
        Button(action: { showGoogleDriveLinkImport = true }) {
            Label("Import from Google Drive Link...", systemImage: "link")
        }
    } label: {
        Label("Import", systemImage: "square.and.arrow.down")
    }
    .help("Import documents")
}
```

- [ ] **Step 3: Add sheet modifiers**

Add these after the existing `.fileImporter` modifier (after line 53):

```swift
.sheet(isPresented: $showGoogleDriveBrowser) {
    GoogleDriveBrowserView(documentVM: viewModel)
}
.sheet(isPresented: $showGoogleDriveLinkImport) {
    GoogleDriveLinkImportView().environmentObject(viewModel)
}
```

- [ ] **Step 4: Commit**

```bash
git add Sources/DocManager/Views/ContentView.swift
git commit -m "feat: integrate Google Drive import into ContentView toolbar menu"
```

---

### Task 5: Verify Build

- [ ] **Step 1: Build the project**

Run: `swift build`
Expected: Build succeeds with no errors

- [ ] **Step 2: Commit if build passes**

```bash
git add -A
git commit -m "chore: verify Google Drive UI builds cleanly"
```
