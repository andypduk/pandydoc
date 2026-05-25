# Import Progress Dialog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the spinner with a detailed progress overlay showing percentage and file count during folder imports.

**Architecture:** Add progress tracking state to DocumentListViewModel, update performFolderImportAsync to count files and report progress, add overlay view to ContentView's document list.

**Tech Stack:** SwiftUI, Swift, @Published state management

---

## File Structure

**Modify:**
- `Sources/DocManager/ViewModels/DocumentListViewModel.swift:1-52` — Add progress tracking properties
- `Sources/DocManager/ViewModels/DocumentListViewModel.swift:1057-1121` — Update performFolderImportAsync to track progress
- `Sources/DocManager/Views/ContentView.swift:448-484` — Add progress overlay to documentList

---

### Task 1: Add Progress Tracking State to ViewModel

**Files:**
- Modify: `Sources/DocManager/ViewModels/DocumentListViewModel.swift:46-52`

- [ ] **Step 1: Add progress tracking properties**

Add these three `@Published` properties after line 46 (after `@Published var archiveProgress: String?`):

```swift
@Published var importProgress: Double?
@Published var importCurrentFile: Int = 0
@Published var importTotalFiles: Int = 0
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/ViewModels/DocumentListViewModel.swift
git commit -m "feat: add import progress tracking state to ViewModel"
```

---

### Task 2: Update performFolderImportAsync to Track Progress

**Files:**
- Modify: `Sources/DocManager/ViewModels/DocumentListViewModel.swift:1057-1121`

- [ ] **Step 1: Replace performFolderImportAsync with progress-tracking version**

Replace the entire `performFolderImportAsync` method (lines 1057-1121) with:

```swift
private func performFolderImportAsync(folderURL: URL) async {
    let fileManager = FileManager.default
    let rootName = folderURL.lastPathComponent
    var folderMap: [String: UUID] = [:]
    var importCount = 0
    var errorCount = 0

    guard let rootFolder = try? storage.createFolder(name: rootName, parentID: currentFolder?.id) else {
        await MainActor.run {
            errorMessage = "Failed to create root folder. A folder with this name may already exist."
        }
        return
    }
    folderMap[""] = rootFolder.id

    guard let enumerator = fileManager.enumerator(
        at: folderURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        await MainActor.run {
            errorMessage = "Failed to read folder contents"
        }
        return
    }

    let items = enumerator.allObjects.compactMap { $0 as? URL }
    let totalFiles = items.filter {
        (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == false
    }.count

    await MainActor.run {
        importTotalFiles = totalFiles
        importCurrentFile = 0
        importProgress = totalFiles > 0 ? 0 : nil
    }

    for fileURL in items {
        let relativePath = String(fileURL.path.dropFirst(folderURL.path.count + 1))
        let relativeDir = (relativePath as NSString).deletingLastPathComponent

        do {
            let attributes = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if attributes.isDirectory == true {
                let folderName = fileURL.lastPathComponent
                let parentID = folderMap[relativeDir.isEmpty ? "" : relativeDir] ?? rootFolder.id
                let existingID = findExistingFolder(named: folderName, parentID: parentID)
                if let existing = existingID {
                    folderMap[relativePath] = existing
                } else if let newFolder = try? storage.createFolder(name: folderName, parentID: parentID) {
                    folderMap[relativePath] = newFolder.id
                } else {
                    errorCount += 1
                }
            } else {
                let parentID = folderMap[relativeDir.isEmpty ? "" : relativeDir] ?? rootFolder.id
                await performFileImportAsync(fileURL: fileURL, to: parentID)
                importCount += 1

                await MainActor.run {
                    importCurrentFile = importCount
                    importProgress = totalFiles > 0 ? Double(importCount) / Double(totalFiles) : 1.0
                }
            }
        } catch {
            errorCount += 1
        }
    }

    await MainActor.run {
        importProgress = nil
        refreshDocuments()
        if importCount > 0 {
            if errorCount > 0 {
                errorMessage = "Imported \(importCount) files (\(errorCount) errors)"
            }
        } else if errorCount > 0 {
            errorMessage = "Failed to import files"
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/ViewModels/DocumentListViewModel.swift
git commit -m "feat: track import progress in performFolderImportAsync"
```

---

### Task 3: Add Progress Overlay to ContentView

**Files:**
- Modify: `Sources/DocManager/Views/ContentView.swift:473-483`

- [ ] **Step 1: Add progress overlay to documentList**

Replace the `.overlay` block in `documentList` (lines 473-483) with:

```swift
.overlay {
    if viewModel.importProgress != nil {
        importProgressOverlay
    } else if viewModel.documents.isEmpty && !viewModel.isLoading {
        ContentUnavailableView(
            viewModel.searchQuery.isEmpty ? emptyTitle : "No Results",
            systemImage: emptyIcon,
            description: Text(viewModel.searchQuery.isEmpty
                ? emptyDescription
                : "No documents match \"\(viewModel.searchQuery)\"")
        )
    }
}
```

- [ ] **Step 2: Add importProgressOverlay view property**

Add this computed property after `emptyDescription` (around line 504):

```swift
private var importProgressOverlay: some View {
    VStack(spacing: 12) {
        ProgressView(value: viewModel.importProgress ?? 0)
            .progressViewStyle(.linear)
            .frame(width: 280)

        Text("Importing \(viewModel.importCurrentFile) of \(viewModel.importTotalFiles) files (\(Int((viewModel.importProgress ?? 0) * 100))%)")
            .font(.body)
            .foregroundColor(.secondary)
    }
    .padding(24)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
}
```

- [ ] **Step 3: Commit**

```bash
git add Sources/DocManager/Views/ContentView.swift
git commit -m "feat: add non-blocking progress overlay for folder imports"
```

---

### Task 4: Verify Build

- [ ] **Step 1: Build the project**

Run: `swift build`
Expected: Build succeeds with no errors

- [ ] **Step 2: Commit if build passes**

```bash
git add -A
git commit -m "chore: verify import progress feature builds cleanly"
```
