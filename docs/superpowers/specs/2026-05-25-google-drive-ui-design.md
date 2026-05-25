# Google Drive Import — Sub-projects 2 & 3: UI Design

## Problem
Users cannot browse or import files from Google Drive within the app. The API layer exists but has no UI.

## Solution
Two new UI components: a folder browser sheet for navigating and selecting Google Drive files, and a share link import sheet for pasting Drive URLs. Both download files and feed them into the existing import pipeline.

## Architecture

### New Files (under `Sources/DocManager/GoogleDrive/`)

**1. `GoogleDriveBrowserViewModel.swift`**
- `@Published var items: [GDriveItem]` — current folder contents
- `@Published var selectedItems: Set<String>` — selected file/folder IDs
- `@Published var currentFolderID: String?` — root when nil
- `@Published var isLoading: Bool`, `@Published var errorMessage: String?`
- `@Published var downloadProgress: Double?` — nil = no download, 0-1 = progress
- `func loadItems()` — calls `GoogleDriveClient.listFiles(parentID:)`
- `func navigateTo(folderID: String)` — enters folder, loads items
- `func navigateUp()` — goes to parent (uses `parents` field from current item)
- `func importSelected(to folderID: UUID?) async` — downloads each selected item to temp dir, then calls `DocumentListViewModel`'s import methods. Reuses `importProgress`, `importCurrentFile`, `importTotalFiles` for progress reporting.

**2. `GoogleDriveBrowserView.swift`**
- Sheet presented from toolbar Import menu
- Top bar: auth status indicator, sign in/out button
- Breadcrumb navigation showing current path
- File list: folder icon + name for folders, file icon + name + size for files
- Checkboxes for multi-select (folders and files)
- Double-click folder to navigate in
- "Import N items" button at bottom (disabled if nothing selected or not authenticated)
- Progress overlay during download (same style as folder import overlay)
- Auto-dismisses when import completes

**3. `GoogleDriveLinkImportView.swift`**
- Small sheet with text field for URL
- "Import" button (disabled if URL empty or not authenticated)
- On import: resolves link via `GoogleDriveClient.resolveShareLink()`, downloads to temp dir, imports via existing pipeline
- Shows inline progress during download
- Auto-dismisses on success, shows error on failure

### ContentView Integration
- Import toolbar button becomes a `Menu`:
  - "Import from Computer..." → existing `fileImporter`
  - "Import from Google Drive..." → `GoogleDriveBrowserView` sheet
  - "Import from Google Drive Link..." → `GoogleDriveLinkImportView` sheet
- Three new `@State` bindings: `showGoogleDriveBrowser`, `showGoogleDriveLinkImport`
- Google Drive sheets use `.sheet(isPresented:)` pattern matching existing sheets

### Data Flow
```
User clicks "Import from Google Drive..." → GoogleDriveBrowserView
  → authenticate if needed → listFiles → user selects items → importSelected
  → download each to temp dir → performFileImportAsync / performFolderImportAsync
  → refreshDocuments → dismiss sheet
```

### Error Handling
- Auth errors → "Sign in to Google Drive" prompt with button
- Network errors → `errorMessage` alert
- Download failures → per-file error count, continues with remaining files
- Share link failures → inline error message below text field
