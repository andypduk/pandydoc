# Fix Folder Rename/Delete Alert Window Targeting

## Problem

Folder rename and delete alerts are attached to the root `NavigationSplitView` in `ContentView.swift` (lines 91-103). When a user right-clicks a folder in the sidebar to rename or delete it, the alert appears anchored to the main window instead of the folder row. This makes the UI feel disconnected — the alert doesn't appear near the folder the user interacted with.

## Root Cause

`.alert("Rename Folder", ...)` and `.alert("Delete Folder", ...)` are modifiers on the top-level `NavigationSplitView` in `ContentView.body`. SwiftUI presents these alerts in the context of the view they're attached to, not the view that triggered the action.

## Solution

Move the `.alert` modifiers from `ContentView` down to `FolderRow`. Each `FolderRow` instance will own its own alert presentation, ensuring the dialog appears anchored to the correct folder row in the sidebar.

### Changes

1. **`FolderRow`**: Add `@Binding` properties for rename/delete alert state. Attach `.alert` modifiers to `FolderRow.body`.
2. **`FolderTreeView`**: Pass bindings through to each `FolderRow`.
3. **`ContentView`**: Remove the duplicate `.alert` modifiers for folder rename/delete. Pass bindings from `ContentView` state down through `FolderTreeView` → `FolderRow`.

### ViewModel

No changes needed. `DocumentListViewModel` already manages `showFolderRenameAlert`, `folderRenameText`, `showDeleteFolderConfirmation`, `folderToDelete`, `startRenameFolder`, `performFolderRename`, `deleteFolder`, `confirmDeleteFolder`.

### Data Flow

```
ContentView (state) → FolderTreeView (bindings) → FolderRow (bindings + .alert)
```

Each `FolderRow` checks if `folderToRename?.id == node.folder.id` to determine whether to show the rename alert, and similarly for delete.
