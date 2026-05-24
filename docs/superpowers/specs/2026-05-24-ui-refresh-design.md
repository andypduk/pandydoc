# PandyDoc UI Refresh Design

**Date:** 2026-05-24
**Status:** Approved

## Overview

Refresh PandyDoc's UI to a modern Apple-native design using macOS Sonoma/Ventura patterns: vibrancy materials, refined typography, smooth animations, file-type colored icons, card-based document rows, and pill-shaped action buttons. All core functionality remains unchanged — this is purely a visual upgrade.

## Design Tokens

### Colors

| Token | Value | Usage |
|-------|-------|-------|
| `statusAvailable` | `#34c759` | Available documents |
| `statusCheckedOut` | `#007aff` | Checked-out documents |
| `statusLocked` | `#ff3b30` | Locked documents |
| `fileTypePDF` | `#ff3b30 → #ff9500` | PDF file icons |
| `fileTypeSpreadsheet` | `#007aff → #5856d6` | XLSX/Numbers icons |
| `fileTypeDocument` | `#5856d6 → #af52de` | DOCX/Pages icons |
| `fileTypePresentation` | `#ff9500 → #ffcc00` | PPTX/Keynote icons |
| `fileTypeText` | `#8e8e93 → #636366` | TXT/RTF icons |
| `selectionBackground` | `rgba(accent, 0.08)` | Selected row background |
| `cardBackground` | `.windowBackground` | Detail panel cards |
| `separatorColor` | `rgba(0, 0, 0, 0.08)` | 0.5px separators |

### Typography

| Element | Style |
|---------|-------|
| Title | `.title3.weight(.semibold)`, letter-spacing `-0.2` |
| Body | `.body.weight(.regular)` |
| Metadata | `.caption.weight(.medium)`, `.secondary` color |
| Label | `.caption2.weight(.semibold)`, uppercase, letter-spacing `0.5` |

### Spacing (8pt grid)

`4, 8, 12, 16, 20, 24, 32`

### Corner Radii

`6` (small badges), `8` (buttons, icons), `10` (cards), `12` (containers)

### Shadows

- Card: `0 1px 4px rgba(0,0,0,0.08)`
- File icon: `0 2px 8px rgba(accent, 0.3)`

## View Changes

### DesignTokens.swift (new)
- Static struct with all color, spacing, typography, and corner radius constants
- `FileTypeColor` enum mapping DocumentType to gradient colors
- `DesignSpacing` struct with consistent padding/spacing values

### DocumentRowView.swift
- Two-line card layout: file-type icon (32×40pt gradient) + name + metadata
- Selection background: `rgba(accent, 0.08)`
- Hover effect: `.hoverEffect(.highlight)`
- Status dot with subtle glow for checked-out state

### DocumentQuickView.swift
- Header: Large file icon (40×50pt) with shadow + title with tight letter-spacing
- Action buttons: Pill-shaped with tinted backgrounds (`.capsule` style)
- Tags: Refined chips with `rgba(accent, 0.1)` background, dashed `+ Add` button
- Preview: White card with `0.5px` border and shadow
- Status bar: Bottom divider with status indicator

### ContentView.swift
- Sidebar: Vibrancy material (`.barMaterial`), section headers, badge counts
- Toolbar: `.toolbarBackground(.bar, for: .automatic)`
- Empty state: Centered PandaHead image + styled message
- Folder tree: Indentation with connecting lines

### SettingsView.swift
- API tab: Match `.formStyle(.grouped)` of other tabs
- Consistent spacing across all tabs

### Sidebar Components
- Section headers: Uppercase labels with letter-spacing
- Badge counts: `rgba(accent, 0.2)` background pills
- Branding header: Gradient icon background

## Implementation Order

1. `DesignTokens.swift` — foundation
2. `DocumentRowView.swift` — most visible change
3. `DocumentQuickView.swift` — detail panel
4. `ContentView.swift` — layout, sidebar, toolbar
5. `SettingsView.swift` — API tab consistency
6. Sidebar components — folder tree, badges

## Risk Mitigation

- All changes are visual only — no logic, models, or services touched
- Each view modified independently, testable in isolation
- Easy to revert individual files if issues arise
- REST API, help system, and all functionality untouched
