# PandyDoc Lock Document Behavior Design

**Date**: 2026-05-24
**Author**: opencode

## Overview

Refine the Lock Document function so locked documents are viewable but not editable. Template documents have additional restrictions when locked: no open, edit, delete, or export — only Quick View and "New from Template" are available.

## Design Decisions

### Approach
Conditional menu items with lock checks in views and ViewModel guards. Minimal changes, follows existing patterns.

## Architecture

### Section 1: Regular Document Lock Behavior

When `document.isLocked == true`:

**Quick View (`DocumentQuickView.swift`):**
- Preview panel works normally (read-only)
- "Open in Default App" toolbar button disabled with tooltip: "Document is locked"

**Context menus (`ContentView.swift`, `DocumentRowView.swift`):**
- "Open" disabled with label "Open (Locked)"
- Export, Delete, Rename, Version History, Flag, Protect remain enabled
- Lock/Unlock buttons available for document owner

**ViewModel (`DocumentListViewModel.swift`):**
- `openDocument(document:)` checks `isLocked`, shows error message if locked

### Section 2: Template Document Lock Behavior

When `document.isLocked == true` AND viewing in Templates folder (`isShowingTemplates == true`):

**Quick View (`DocumentQuickView.swift`):**
- Preview panel works normally
- "Open in Default App" disabled with tooltip: "Template is locked"
- "Convert to PDF" remains enabled

**Context menus (`ContentView.swift`):**
- "Open" disabled with label "Open (Locked)"
- "Export..." disabled with label "Export (Locked)"
- "Delete" disabled with label "Delete (Locked)"
- "New from Template" enabled
- "Remove from Templates" enabled
- Version History, Rename, Flag, Protect enabled
- Lock/Unlock available for template owner

**ViewModel (`DocumentListViewModel.swift`):**
- `openDocument(document:)` checks `isLocked`, shows appropriate error
- `exportDocument(_:)` checks `isLocked && isShowingTemplates`, shows error
- `deleteDocument(document:)` checks `isLocked && isShowingTemplates`, shows error
- `canOpenDocument(document:)` helper returns `!document.isLocked`
- `canExportTemplate(document:)` helper returns `!document.isLocked || !isShowingTemplates`
- `canDeleteTemplate(document:)` helper returns `!document.isLocked || !isShowingTemplates`

### Section 3: Implementation Details

**Files modified:**
1. `DocumentQuickView.swift` — Disable toolbar open button when locked
2. `ContentView.swift` — Disable Open/Export/Delete context menu items for locked documents
3. `DocumentRowView.swift` — Disable Open/Export/Delete in row context menu
4. `DocumentListViewModel.swift` — Add lock checks to `openDocument()`, `exportDocument()`, `deleteDocument()`

**Error messages:**
- Regular locked: "Document is locked. Unlock it to edit."
- Template locked (open): "Template is locked. Create a new document from this template instead."
- Template locked (export): "Template is locked. Create a new document from this template instead."
- Template locked (delete): "Template is locked. Unlock it to delete."

**Helper methods in ViewModel:**
- `canOpenDocument(_ document: Document) -> Bool` — returns `!document.isLocked`
- `canExportTemplate(_ document: Document) -> Bool` — returns `!document.isLocked || !isShowingTemplates`
- `canDeleteTemplate(_ document: Document) -> Bool` — returns `!document.isLocked || !isShowingTemplates`

## Testing

- Verify locked regular document: Quick View works, Open disabled, Export/Delete enabled
- Verify locked template: Quick View works, Open/Export/Delete disabled, New from Template enabled
- Verify unlock restores all functionality
- Verify non-locked documents unaffected
