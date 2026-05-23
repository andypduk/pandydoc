# PDF Service Installer - Design Spec

**Date**: 2026-05-23
**Status**: Approved

## Problem

The "Install" button in the Printer Setup sheet (first option: "Save to PandyDoc" PDF Service) fails to install. The current approach uses `osacompile` to compile an AppleScript into a `.app` bundle. This is fragile on modern macOS due to security restrictions, quoting issues, and `osacompile` reliability.

## Solution

Replace the AppleScript-based PDF Service handler with a native Swift executable target (`SaveToPandyDoc`) built as part of the SPM project. During installation, the compiled binary is copied into the standard `~/Library/PDF Services/Save to PandyDoc.app` bundle structure.

## Architecture

### New Target: `SaveToPandyDoc`

An executable target in `Package.swift` at `Sources/SaveToPandyDoc/main.swift`.

**Behavior**: When macOS launches this app from the PDF Services menu, it receives file paths as command-line arguments. For each path:

1. Validates the file exists and is readable
2. Generates a UUID prefix for uniqueness
3. Copies the file to `~/Library/Application Support/PandyDoc/Incoming/<UUID>-<filename>.pdf`
4. Shows a macOS notification: "Document saved to PandyDoc"
5. Exits

**Configuration**: The app bundle's `Info.plist` sets `LSUIElement = true` so it runs as a background app with no Dock icon.

### Updated: `PDFPrinterService.installPDFService()`

Instead of:
1. Writing AppleScript to a temp file
2. Running `osacompile` to compile it
3. Modifying the resulting app's `Info.plist`

It now:
1. Locates the compiled `SaveToPandyDoc` binary (bundled alongside the main `PandyDoc` executable in `Contents/MacOS/`)
2. Creates the app bundle structure at `~/Library/PDF Services/Save to PandyDoc.app/`:
   ```
   Save to PandyDoc.app/
   └── Contents/
       ├── Info.plist   (LSUIElement=true, CFBundleExecutable=SaveToPandyDoc)
       └── MacOS/
           └── SaveToPandyDoc  (copied binary)
   ```
3. Sets executable permissions on the binary

No `osacompile` dependency — only file system operations.

## Files Changed

| File | Change |
|------|--------|
| `Package.swift` | Add `SaveToPandyDoc` executable target, add it as a product |
| `Sources/SaveToPandyDoc/main.swift` | New file — handles incoming PDFs |
| `Sources/DocManager/Services/PDFPrinterService.swift` | Rewrite `installPDFService()` |
| `Sources/DocManager/Views/PrinterSetupSheet.swift` | No changes required |

## Error Handling

- `installPDFService()` returns `Bool` as before
- If the binary can't be found, logs an error and returns `false`
- If file operations fail, logs the error and returns `false`
- The UI already handles the return value with success/failure messages
