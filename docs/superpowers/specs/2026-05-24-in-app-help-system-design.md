# PandyDoc In-App Help System Design

**Date**: 2026-05-24
**Author**: opencode

## Overview

Replace the current scattered help sheets with a unified, tabbed in-app help system. Each tab contains quick reference cards and expandable walkthrough sections covering all PandyDoc features.

## Design Decisions

### Approach
Native SwiftUI `TabView` with `.tabViewStyle(.segmented)` for macOS-native navigation. Content is hardcoded in Swift for simplicity. Reusable UI components in a separate file.

### Audience
End users — people who will use the app day-to-day.

### Format
Mixed: quick reference at the top of each tab, with expandable "Learn more" sections containing full step-by-step walkthroughs.

## Architecture

### Section 1: Tab Structure

6 tabs covering all major features:

1. **Getting Started** (`sparkles`) — First launch, app overview, importing first document, printer setup
2. **Managing Documents** (`doc.text`) — Import, open, check-out/edit, check-in, lock/unlock, export, delete, flag, rename
3. **Organizing** (`folder`) — Folders (create, move, protect, archive), tags, search, sidebar navigation
4. **Templates & Versions** (`doc.on.doc`) — Create/use templates, version history, restore versions, "New from Template"
5. **Printing** (`printer`) — Install printer, print from any app, PDF capture, notifications
6. **Advanced** (`gearshape`) — Settings, iCloud backup, file watching, keyboard shortcuts, troubleshooting

### Section 2: UI/UX Design

**Layout**:
- `HelpView` uses `TabView` with `.tabViewStyle(.segmented)`
- Each tab has a title and SF Symbol icon
- Content wrapped in `ScrollView` with padding

**Content Structure per Tab**:
1. **Header**: Brief intro text for the category
2. **Quick Reference Cards**: Grid of cards showing common actions with 1-2 sentence descriptions
3. **Walkthrough Sections**: `DisclosureGroup` (expandable) sections with detailed step-by-step tutorials
   - Prerequisites (if any)
   - Numbered steps with bold UI elements
   - "What happens next" notes
   - Tips/Warnings (e.g., "⚠️ Locked documents cannot be edited")

**Integration**:
- Replace `HelpSheetView`, `GettingStartedSheetView`, and `KeyboardShortcutsSheetView` with `HelpView`
- Update `DocManagerApp.swift` menu commands to open `HelpView`
- Add "Help" button to toolbar that opens `HelpView`
- `HelpView` takes optional `initialTab: HelpTab?` parameter to open directly to a specific tab

### Section 3: Implementation Details

**Files Created**:
- `Sources/DocManager/Views/HelpView.swift` — Main help view with `TabView` and all content
- `Sources/DocManager/Views/HelpComponents.swift` — Reusable UI components (`QuickRefCard`, `WalkthroughSection`, `TipBox`, etc.)

**Files Modified**:
- `Sources/DocManager/DocManagerApp.swift` — Update menu commands, remove old sheet states
- `Sources/DocManager/Views/ContentView.swift` — Remove old help sheet references, add `HelpView` sheet state

**Key Implementation Details**:
- `HelpTab` enum maps to the 6 categories
- Menu commands use `NotificationCenter` to post `showHelp(initialTab:)` with appropriate tab
- Content hardcoded in Swift (no external Markdown/HTML parsing)
- `HelpComponents.swift` provides clean, reusable SwiftUI views for consistent styling

## Data Flow

```
[User clicks Help/Getting Started/Shortcuts] --> [NotificationCenter posts showHelp(tab)]
                                                      |
                                                      v
                                               [ContentView receives notification]
                                                      |
                                                      v
                                               [Opens HelpView sheet with initialTab]
                                                      |
                                                      v
                                               [User browses tabs, expands walkthroughs]
```

## Error Handling

- If help content fails to load (unlikely with hardcoded content), show fallback text
- Graceful degradation on smaller window sizes (scrollable content adapts)

## Testing

- Verify all 6 tabs display correctly with content
- Verify quick reference cards render properly
- Verify walkthrough sections expand/collapse correctly
- Verify menu commands open correct tabs
- Verify toolbar help button opens help view
- Test on macOS 14+ (Sonoma and later)
