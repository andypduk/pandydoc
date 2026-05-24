# Lock Document Behavior Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add lock checks to prevent opening, editing, exporting, and deleting locked documents, with additional restrictions for locked templates.

**Architecture:** Add helper methods to ViewModel for permission checks, guard ViewModel actions, and disable context menu items/toolbar buttons in views based on lock status.

**Tech Stack:** Swift, SwiftUI, macOS AppKit

---

### Task 1: Add Permission Helper Methods to ViewModel

**Files:**
- Modify: `Sources/DocManager/ViewModels/DocumentListViewModel.swift`

- [ ] **Step 1: Add helper methods for document permissions**

Add these helper methods to `DocumentListViewModel` (place them near the `lockDocument`/`unlockDocument` methods around line 648):

```swift
    func canOpenDocument(_ document: Document) -> Bool {
        return !document.isLocked
    }

    func canExportTemplate(_ document: Document) -> Bool {
        return !document.isLocked || !isShowingTemplates
    }

    func canDeleteTemplate(_ document: Document) -> Bool {
        return !document.isLocked || !isShowingTemplates
    }
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/ViewModels/DocumentListViewModel.swift
git commit -m "feat: add document permission helper methods for lock checks"
```

---

### Task 2: Add Lock Guards to ViewModel Actions

**Files:**
- Modify: `Sources/DocManager/ViewModels/DocumentListViewModel.swift`

- [ ] **Step 1: Add lock check to `openDocument(document:)`**

Update the `openDocument` method (around line 678) to check if the document is locked:

```swift
    func openDocument(document: Document) {
        if document.isLocked {
            if isShowingTemplates {
                errorMessage = "Template is locked. Create a new document from this template instead."
            } else {
                errorMessage = "Document is locked. Unlock it to edit."
            }
            return
        }
        let url = URL(fileURLWithPath: document.filePath)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(url, configuration: config)
    }
```

- [ ] **Step 2: Add lock check to `exportDocument(_:)`**

Update the `exportDocument` method (around line 685) to check if the template is locked:

```swift
    func exportDocument(_ document: Document) {
        if document.isLocked && isShowingTemplates {
            errorMessage = "Template is locked. Create a new document from this template instead."
            return
        }
        let savePanel = NSSavePanel()
        savePanel.title = "Export Document"
        savePanel.nameFieldStringValue = document.fileName
        savePanel.canCreateDirectories = true

        let fileURL = URL(fileURLWithPath: document.filePath)
        if let utType = UTType(filenameExtension: fileURL.pathExtension) {
            savePanel.allowedContentTypes = [utType]
        }

        savePanel.begin { response in
            guard response == .OK, let destURL = savePanel.url else { return }
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(atPath: document.filePath, toPath: destURL.path)
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to export document: \(error.localizedDescription)"
                }
            }
        }
    }
```

- [ ] **Step 3: Add lock check to `deleteDocument(document:)`**

Update the `deleteDocument` method (around line 711) to check if the template is locked:

```swift
    func deleteDocument(document: Document) {
        if document.isLocked && isShowingTemplates {
            errorMessage = "Template is locked. Unlock it to delete."
            return
        }
        do {
            try storage.deleteDocument(id: document.id)
            refreshDocuments()
            if selectedDocument?.id == document.id {
                selectedDocument = nil
            }
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }
```

- [ ] **Step 4: Commit**

```bash
git add Sources/DocManager/ViewModels/DocumentListViewModel.swift
git commit -m "feat: add lock guards to openDocument, exportDocument, deleteDocument"
```

---

### Task 3: Update Quick View Toolbar

**Files:**
- Modify: `Sources/DocManager/Views/DocumentQuickView.swift`

- [ ] **Step 1: Disable "Open in Default App" button when document is locked**

Update the toolbar's "Open in Default App" button (around line 171-177) to be disabled when the document is locked:

```swift
            Button(action: {
                let url = URL(fileURLWithPath: document.filePath)
                NSWorkspace.shared.open(url)
            }) {
                Image(systemName: "arrow.up.right.square")
            }
            .disabled(document.isLocked)
            .help(document.isLocked ? "Document is locked" : "Open in Default App")
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/Views/DocumentQuickView.swift
git commit -m "feat: disable Quick View open button for locked documents"
```

---

### Task 4: Update ContentView Context Menu

**Files:**
- Modify: `Sources/DocManager/Views/ContentView.swift`

- [ ] **Step 1: Update "Open" menu items to be disabled when locked**

In `documentContextMenu(for:)` (around line 659-661 and 687-689), disable the "Open" buttons when the document is locked:

First "Open" button (around line 659):
```swift
        Button(action: { viewModel.openDocument(document: document) }) {
            Label(document.isLocked ? "Open (Locked)" : "Open", systemImage: "arrow.up.right.square")
        }
        .disabled(document.isLocked)
```

Second "Open" button (around line 687):
```swift
        Button(action: { viewModel.openDocument(document: document) }) {
            Label(document.isLocked ? "Open (Locked)" : "Open", systemImage: "arrow.up.right.square")
        }
        .disabled(document.isLocked)
```

- [ ] **Step 2: Update "Export..." menu item to be disabled for locked templates**

Around line 669-671:
```swift
        Button(action: { viewModel.exportDocument(document) }) {
            Label(document.isLocked && viewModel.isShowingTemplates ? "Export (Locked)" : "Export...", systemImage: "square.and.arrow.up")
        }
        .disabled(document.isLocked && viewModel.isShowingTemplates)
```

- [ ] **Step 3: Update "Delete" menu item to be disabled for locked templates**

Around line 710-712 (the destructive button):
```swift
        Button(role: .destructive, action: { viewModel.deleteDocument(document: document) }) {
            Label(document.isLocked && viewModel.isShowingTemplates ? "Delete (Locked)" : "Delete", systemImage: "trash")
        }
        .disabled(document.isLocked && viewModel.isShowingTemplates)
```

- [ ] **Step 4: Commit**

```bash
git add Sources/DocManager/Views/ContentView.swift
git commit -m "feat: disable Open/Export/Delete context menu items for locked documents"
```

---

### Task 5: Update DocumentRowView Context Menu

**Files:**
- Modify: `Sources/DocManager/Views/DocumentRowView.swift`

- [ ] **Step 1: Update "Open" menu item to be disabled when locked**

In `documentContextMenu` (around line 178-180):
```swift
        Button(action: { viewModel.openDocument(document: document) }) {
            Label(document.isLocked ? "Open (Locked)" : "Open", systemImage: "arrow.up.right.square")
        }
        .disabled(document.isLocked)
```

- [ ] **Step 2: Update "Export..." menu item to be disabled for locked templates**

Around line 174-176:
```swift
        Button(action: { viewModel.exportDocument(document) }) {
            Label(document.isLocked && viewModel.isShowingTemplates ? "Export (Locked)" : "Export...", systemImage: "square.and.arrow.up")
        }
        .disabled(document.isLocked && viewModel.isShowingTemplates)
```

- [ ] **Step 3: Update "Delete" menu item to be disabled for locked templates**

Around line 206-208:
```swift
        Button(role: .destructive, action: { viewModel.deleteDocument(document: document) }) {
            Label(document.isLocked && viewModel.isShowingTemplates ? "Delete (Locked)" : "Delete", systemImage: "trash")
        }
        .disabled(document.isLocked && viewModel.isShowingTemplates)
```

- [ ] **Step 4: Commit**

```bash
git add Sources/DocManager/Views/DocumentRowView.swift
git commit -m "feat: disable Open/Export/Delete row context menu items for locked documents"
```

---

### Task 6: Build and Verify

**Files:**
- No file changes

- [ ] **Step 1: Build the project**

```bash
swift build
```

Expected: Build succeeds with no errors.

- [ ] **Step 2: Final commit (if any changes)**

```bash
git status
```

If there are uncommitted changes, commit them. Otherwise, proceed.
