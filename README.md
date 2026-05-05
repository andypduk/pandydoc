# PandyDoc - macOS Document Management System

A comprehensive document management system for macOS with check-in/check-out, versioning, and PDF print-to-app functionality.

## Features

- **Check-in/Check-out**: Lock documents for editing and track who has them checked out
- **Document Versioning**: Automatic versioning with change notes and restore capability
- **Print to PandyDoc**: Install a virtual PDF printer to capture documents from any application
- **In-place Editing**: Double-click documents to open in their native applications
- **Auto Save-back**: Changes are automatically saved back to the document management system
- **File Watching**: Monitors open documents for external changes

## Project Structure

```
pandydoc/
├── DocManager/
│   ├── Models/
│   │   ├── Document.swift          # Document and version models
│   │   └── DocumentTypes.swift     # Document type enums and helpers
│   ├── Services/
│   │   ├── DocumentStorage.swift       # Document storage and metadata
│   │   ├── CheckInOutService.swift     # Check-in/check-out logic
│   │   ├── DocumentEditorService.swift # Editor integration
│   │   ├── FileWatcher.swift           # File change monitoring
│   │   ├── PDFPrinterService.swift     # Printer setup and management
│   │   └── DocumentWatcherService.swift # Background file watching
│   ├── ViewModels/
│   │   └── DocumentListViewModel.swift # Main view model
│   ├── Views/
│   │   ├── ContentView.swift           # Main window
│   │   ├── DocumentRowView.swift       # Document list row
│   │   ├── DocumentDetailView.swift    # Document detail panel
│   │   ├── CheckInSheetView.swift      # Check-in dialog
│   │   ├── VersionHistoryView.swift    # Version history viewer
│   │   ├── PrinterSetupSheet.swift     # Printer installation wizard
│   │   └── SettingsView.swift          # Preferences panel
│   ├── Utilities/
│   │   └── AppDelegate.swift           # App delegate and lifecycle
│   ├── Resources/
│   │   └── Info.plist                  # App configuration and UTIs
│   └── DocManagerApp.swift             # App entry point
├── PrinterExtension/
│   ├── PrintExtension.swift        # Print extension controller
│   └── Info.plist                  # Extension configuration
├── Shared/
│   └── PandyDocConstants.swift     # Shared constants
├── Scripts/
│   ├── install_printer.sh          # CUPS printer installation
│   ├── pdf_monitor.sh              # PDF directory monitor
│   └── com.pandydoc.pdfmonitor.plist # Launch daemon
└── DocManager.xcodeproj/
    └── project.json                # Project configuration
```

## Building

1. Open `DocManager.xcodeproj` in Xcode 15+
2. Select the `DocManager` target
3. Set development team in Signing & Capabilities
4. Build and run (Cmd+R)

## Installing the Printer

### Option 1: Via the App
1. Open PandyDoc
2. Click the Printer Setup button in the toolbar
3. Follow the installation instructions

### Option 2: Via Terminal
```bash
sudo ./Scripts/install_printer.sh
```

### Manual Installation
```bash
# Create directories
mkdir -p ~/Library/Application\ Support/PandyDoc/Incoming
sudo mkdir -p /Library/Printers/PandyDoc
sudo mkdir -p /Library/Printers/PPDs/Contents/Resources

# Copy backend and PPD (requires building first)
sudo cp build/Release/pandydoc /Library/Printers/PandyDoc/
sudo cp build/PandyDoc.ppd /Library/Printers/PPDs/Contents/Resources/

# Set permissions
sudo chmod 0755 /Library/Printers/PandyDoc/pandydoc
sudo chown root:_lp /Library/Printers/PandyDoc/pandydoc

# Register printer
sudo lpadmin -p PandyDoc -E -v pandydoc://localhost -P /Library/Printers/PPDs/Contents/Resources/PandyDoc.ppd
cupsenable PandyDoc
cupsaccept PandyDoc
```

## Usage

### Importing Documents
- Click the Import button in the toolbar
- Drag and drop files onto the app window
- Open files with PandyDoc via Finder (right-click > Open With)

### Check-out and Edit
1. Select a document in the sidebar
2. Click "Check Out & Edit" or right-click > Check Out
3. The document opens in its default application
4. Make your changes
5. Return to PandyDoc and click "Check In" to save changes as a new version

### Check-in
1. Select a checked-out document
2. Click "Check In"
3. Optionally add change notes
4. Confirm to save as a new version

### Version History
1. Select a document
2. Click "Versions" or right-click > Version History
3. View all versions with timestamps and authors
4. Click "Restore" on any version to revert

### Print to PandyDoc
1. In any application, select File > Print (Cmd+P)
2. Choose "PandyDoc" from the printer list
3. The PDF is automatically saved to PandyDoc
4. A notification appears when the document is received

## Storage Location

Documents are stored in:
```
~/Library/Application Support/PandyDoc/
├── Documents/          # Current versions
├── Versions/           # Historical versions
│   └── [document-uuid]/
│       ├── v1_filename.pdf
│       ├── v2_filename.pdf
│       └── ...
├── Incoming/           # Temp storage for printed PDFs
└── metadata.json       # Document metadata cache
```

## System Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building)
- Administrator access (for printer installation)

## Architecture

### Document Flow

```
[User Action] --> [CheckInOutService] --> [DocumentStorage] --> [File System]
       ^                                         |
       |                                         v
       +----------- [FileWatcher] <--------------+
```

### Print Flow

```
[Any App] --> [Print Dialog] --> [CUPS] --> [pandydoc backend]
                                              |
                                              v
                                    [~/Library/.../Incoming/]
                                              |
                                              v
                                    [PDFPrinterService]
                                              |
                                              v
                                    [DocumentStorage]
                                              |
                                              v
                                    [Notification -> UI]
```

## License

Copyright 2026 PandyDoc. All rights reserved.
