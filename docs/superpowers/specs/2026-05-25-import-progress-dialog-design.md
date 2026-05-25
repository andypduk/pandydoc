# Import Progress Dialog Design

## Problem
Folder imports show only a spinning wheel with no indication of how much work remains. Users importing large folders have no visibility into progress.

## Solution
Replace the spinner with a detailed progress overlay during folder imports showing percentage, file count, and a progress bar.

## Architecture

### ViewModel Changes (DocumentListViewModel.swift)

Add three new `@Published` properties:
- `importProgress: Double?` — nil means no active import, 0.0–1.0 is progress
- `importCurrentFile: Int` — number of files processed so far
- `importTotalFiles: Int` — total files to import

In `performFolderImportAsync`:
1. First pass: count total files in the folder before importing
2. Set `importTotalFiles` and `importProgress = 0`
3. Per file: increment `importCurrentFile`, update `importProgress = Double(current) / Double(total)`
4. On completion or error: set `importProgress = nil`

### View Changes (ContentView.swift)

Add overlay to `documentList` when `importProgress != nil`:
- Semi-transparent background (`.ultraThinMaterial`)
- Centered card with:
  - `ProgressView(value: viewModel.importProgress)`
  - Text: "Importing X of Y files (Z%)"
- Non-blocking — user can still interact with the app
- Auto-dismisses when `importProgress` becomes nil

## Data Flow
```
user selects folder → importFolderWithAccessCheck → performFolderImportAsync
  → count files → set importTotalFiles, importProgress = 0
  → for each file: importCurrentFile++, update importProgress
  → refreshDocuments → importProgress = nil → overlay disappears
```

## Error Handling
- If import fails, `importProgress` is set to nil (overlay dismisses)
- Error message shown via existing `errorMessage` alert
