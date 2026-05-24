# PandyDoc Application Icon Design

**Date**: 2026-05-24
**Author**: opencode

## Overview

Add the PandyDoc panda footprint logo as an application icon in three locations:
1. macOS app icon (Finder, Dock, Launchpad)
2. Window title bar (icon + "PandyDoc" text)
3. About PandyDoc window

## Design Decisions

### Icon Style
- **Approach**: New simplified SVG → ICNS (clean, scalable, maintainable)
- **Design**: "Rounder & Fluffier" panda head — wider head, bigger ears with inner detail, larger expressive eyes, pink cheeks, cute smile
- **Color palette**: Matches existing brand — blue gradient background (`#4A90D9` → `#2C5F8A`), white panda face, `#1a1a1a` features, `#FFB6C1` cheeks

### Title Bar Style
- **Layout**: Panda icon + "PandyDoc" text combined (Option C)
- **Icon size**: ~20x20px in title bar
- **Rendering**: PDF variant for crisp Retina display rendering

## Architecture

### Section 1: App Icon (Finder/Dock/Launchpad)

**Files**:
- `Resources/PandaHead.svg` — source artwork (panda head, rounder/fluffier design)
- `Resources/PandaHead.iconset/` — generated icon set with all macOS sizes
- `Resources/PandaHead.icns` — final ICNS file

**Steps**:
1. Create `PandaHead.svg` with the rounder/fluffier panda design
2. Generate `.iconset` folder with sizes: 16x16, 32x32, 64x64, 128x128, 256x256, 512x512, 1024x1024 (plus @2x variants)
3. Run `iconutil -c icns` to produce `PandaHead.icns`
4. Update `Package.swift` to reference `PandaHead.icns` instead of `PandaIcon.icns`
5. Keep `PandaIcon.icns` and `PandaIcon.svg` for reference (full panda+Mac design)

### Section 2: Title Bar Icon + Text

**Files modified**:
- `Sources/DocManager/Views/ContentView.swift` — main window

**Implementation**:
1. Export `PandaHead.svg` to `PandaHead.pdf` for Xcode asset catalog compatibility (PDF scales crisply at any resolution)
2. Add both `PandaHead.svg` and `PandaHead.pdf` to `Sources/DocManager/Resources/` as bundle resources
3. In `ContentView.swift`, use `.toolbar` modifier with a `ToolbarItem(placement: .principal)` containing an `HStack` with the icon and text
4. Set `NSWindow.titleVisibility = .hidden` via `NSWindowDelegate` or SwiftUI's `.windowStyle(.hiddenTitleBar)` to show custom title
5. The `HStack` contains:
   - `Image("PandaHead")` resized to ~20x20
   - `Text("PandyDoc")` with system font
6. Use `.toolbarRole(.automatic)` for macOS 14+ unified title bar behavior

### Section 3: About Window Icon

**Files created/modified**:
- `Sources/DocManager/Views/AboutView.swift` (new) — About window content
- `Sources/DocManager/Utilities/AppDelegate.swift` — register About menu action

**Implementation**:
1. Create `AboutView` with centered panda icon (128x128 or 256x256)
2. Display app name, version number, and copyright below
3. Register as the app's About panel via `NSApplication` or custom menu item
4. Accessible via PandyDoc > About PandyDoc in the menu bar

## Data Flow

```
PandaHead.svg → iconutil → PandaHead.icns → App Bundle → Finder/Dock/Launchpad
PandaHead.svg → PDF export → Xcode Assets → ContentView toolbar → Title bar
PandaHead.svg → PDF export → Xcode Assets → AboutView → About window
```

## Error Handling

- If icon resource fails to load, fall back to default macOS app icon (no crash)
- Title bar gracefully degrades to text-only if image cannot be rendered
- About window shows placeholder if icon is missing

## Testing

- Verify app icon displays correctly in Finder, Dock, and Launchpad at all sizes
- Verify title bar icon renders crisply on Retina displays
- Verify About window icon displays at correct size
- Test on macOS 14+ (Sonoma and later)

## Files Summary

### New Files
- `Resources/PandaHead.svg` — simplified panda head source artwork
- `Resources/PandaHead.icns` — macOS app icon
- `Sources/DocManager/Views/AboutView.swift` — About window

### Modified Files
- `Package.swift` — update resource reference from `PandaIcon.icns` to `PandaHead.icns`
- `Sources/DocManager/Views/ContentView.swift` — add title bar icon
- `Sources/DocManager/Utilities/AppDelegate.swift` — register About window

### Unchanged (Reference)
- `Resources/PandaIcon.svg` — original full panda+Mac design (kept)
- `Resources/PandaIcon.icns` — original ICNS (kept)
