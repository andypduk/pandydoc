# Document Tags & Tag Cloud Feature

## Overview

Add custom tagging to all documents with a tag cloud view, sidebar tag filter, and full search across names and tags.

## Existing State

- `Document.tags: [String]` field exists in model and database
- Database stores tags as base64-encoded JSON array
- `selectedTags` exists in ViewModel but has no UI
- Tag search uses buggy LIKE on base64 string
- Print extension collects tags but never saves them

## Design

### 1. Tag Editing in DocumentQuickView

Add a tag input section below the document name in the detail panel:
- Display existing tags as rounded chips with × remove button
- Inline text field: type and press Enter/comma to add
- Auto-complete from existing tags in the library
- Tags are normalized to lowercase, trimmed, deduplicated

### 2. Sidebar Tags Section

New "Tags" section below Folders in the sidebar:
- Shows all unique tags sorted alphabetically
- Each tag shows a count badge (number of documents with that tag)
- Clicking a tag toggles it as a filter (multi-select)
- Active tags highlighted with accent color
- "Clear filters" button when tags are selected

### 3. Tag Cloud Panel

A separate view accessible via toolbar button:
- Shows all tags sized by frequency (larger = more documents)
- Color-coded by category (user-defined or auto-assigned)
- Clicking a tag filters the document list
- Full-screen overlay or sheet presentation

### 4. Fix Tag Search

Replace base64 LIKE matching with proper JSON extraction:
- Use SQLite's `json_each()` or decode in Swift
- Search filters by name AND selected tags simultaneously
- Case-insensitive matching

### 5. Wire Print Extension Tags

Save tags from print dialog to the document when storing received PDFs.

## Data Flow

```
User types tag → normalize → add to document.tags → save to DB → refresh tag list → update sidebar counts
User clicks tag in sidebar → add to selectedTags → filter documents by name query + tags → update document list
```

## Files Changed

- `DocumentQuickView.swift` — add tag editing UI
- `ContentView.swift` — add sidebar tags section, tag cloud button
- `DocumentListViewModel.swift` — add tag management methods, tag cloud state
- `DatabaseManager.swift` — fix tag search query
- `DocumentStorage.swift` — add `getAllTags()` method
- `DocumentRowView.swift` — optionally show tags on rows
- `DocumentStorage.swift` / `DocumentWatcherService.swift` — pass print tags through
