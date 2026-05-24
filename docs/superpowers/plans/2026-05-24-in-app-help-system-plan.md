# In-App Help System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace scattered help sheets with a unified, tabbed in-app help system featuring quick reference cards and expandable walkthrough sections.

**Architecture:** Create `HelpView.swift` with a `TabView` for 6 categories, `HelpComponents.swift` for reusable UI components, and integrate into `ContentView.swift` and `DocManagerApp.swift`.

**Tech Stack:** Swift, SwiftUI, macOS AppKit

---

### Task 1: Create HelpTab Enum and Notification

**Files:**
- Create: `Sources/DocManager/Views/HelpView.swift` (partial — enum and notification only)

- [ ] **Step 1: Create HelpView.swift with HelpTab enum**

Create `Sources/DocManager/Views/HelpView.swift` with the `HelpTab` enum and notification extension:

```swift
import SwiftUI

enum HelpTab: Int, CaseIterable, Identifiable {
    case gettingStarted = 0
    case managingDocuments = 1
    case organizing = 2
    case templatesVersions = 3
    case printing = 4
    case advanced = 5
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .gettingStarted: return "Getting Started"
        case .managingDocuments: return "Managing Documents"
        case .organizing: return "Organizing"
        case .templatesVersions: return "Templates & Versions"
        case .printing: return "Printing"
        case .advanced: return "Advanced"
        }
    }
    
    var icon: String {
        switch self {
        case .gettingStarted: return "sparkles"
        case .managingDocuments: return "doc.text"
        case .organizing: return "folder"
        case .templatesVersions: return "doc.on.doc"
        case .printing: return "printer"
        case .advanced: return "gearshape"
        }
    }
}

extension Notification.Name {
    static let showHelpWithTab = Notification.Name("showHelpWithTab")
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/Views/HelpView.swift
git commit -m "feat: add HelpTab enum and notification for help system"
```

---

### Task 2: Create HelpComponents.swift

**Files:**
- Create: `Sources/DocManager/Views/HelpComponents.swift`

- [ ] **Step 1: Create reusable help UI components**

Create `Sources/DocManager/Views/HelpComponents.swift`:

```swift
import SwiftUI

struct QuickRefCard: View {
    let title: String
    let description: String
    let icon: String
    let action: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            if action != nil {
                Spacer()
                Button("Learn More") {
                    action?()
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct WalkthroughSection: View {
    let title: String
    let steps: [String]
    let tip: String?
    let warning: String?
    
    var body: some View {
        DisclosureGroup(title) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        Text(step)
                            .font(.subheadline)
                    }
                }
                
                if let warning = warning {
                    TipBox(text: warning, style: .warning)
                }
                
                if let tip = tip {
                    TipBox(text: tip, style: .tip)
                }
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 4)
    }
}

struct TipBox: View {
    let text: String
    let style: TipStyle
    
    enum TipStyle {
        case tip, warning
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: style == .warning ? "exclamationmark.triangle.fill" : "lightbulb.fill")
                .foregroundColor(style == .warning ? .orange : .yellow)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(8)
        .background(style == .warning ? Color.orange.opacity(0.1) : Color.yellow.opacity(0.1))
        .cornerRadius(6)
    }
}

struct HelpSectionHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 16)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/Views/HelpComponents.swift
git commit -m "feat: add reusable help UI components"
```

---

### Task 3: Create HelpView with TabView Shell

**Files:**
- Modify: `Sources/DocManager/Views/HelpView.swift`

- [ ] **Step 1: Add HelpView struct with TabView shell**

Append to `Sources/DocManager/Views/HelpView.swift` (after the enum):

```swift
struct HelpView: View {
    @State private var selectedTab: HelpTab = .gettingStarted
    var initialTab: HelpTab?
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                GettingStartedTab().tag(HelpTab.gettingStarted)
                ManagingDocumentsTab().tag(HelpTab.managingDocuments)
                OrganizingTab().tag(HelpTab.organizing)
                TemplatesVersionsTab().tag(HelpTab.templatesVersions)
                PrintingTab().tag(HelpTab.printing)
                AdvancedTab().tag(HelpTab.advanced)
            }
            .tabViewStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)
        }
        .frame(width: 700, height: 500)
        .onAppear {
            if let initial = initialTab {
                selectedTab = initial
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/Views/HelpView.swift
git commit -m "feat: add HelpView with TabView shell"
```

---

### Task 4: Create GettingStartedTab Content

**Files:**
- Create: `Sources/DocManager/Views/HelpTabs/GettingStartedTab.swift`

- [ ] **Step 1: Create Getting Started tab content**

Create `Sources/DocManager/Views/HelpTabs/GettingStartedTab.swift`:

```swift
import SwiftUI

struct GettingStartedTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HelpSectionHeader(
                    title: "Welcome to PandyDoc",
                    subtitle: "Your macOS document management system with check-in/check-out, versioning, and PDF printing."
                )
                
                // Quick Reference Cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    QuickRefCard(
                        title: "Import Your First Document",
                        description: "Add documents by clicking Import or dragging files into PandyDoc.",
                        icon: "square.and.arrow.down"
                    ) {}
                    
                    QuickRefCard(
                        title: "Set Up the Printer",
                        description: "Install the PandyDoc printer to capture PDFs from any app.",
                        icon: "printer"
                    ) {}
                    
                    QuickRefCard(
                        title: "Check Out & Edit",
                        description: "Open documents for editing with automatic version tracking.",
                        icon: "pencil"
                    ) {}
                    
                    QuickRefCard(
                        title: "Create a Folder",
                        description: "Organize documents into folders for easy navigation.",
                        icon: "folder.badge.plus"
                    ) {}
                }
                
                Divider()
                
                // Walkthrough Sections
                HelpSectionHeader(title: "Step-by-Step Guides", subtitle: "")
                
                WalkthroughSection(
                    title: "Import Your First Document",
                    steps: [
                        "Click the **Import** button in the toolbar, or press Cmd+I.",
                        "Select one or more files from the file picker.",
                        "Click **Open** to import them into PandyDoc.",
                        "Your documents appear in the **All Documents** section of the sidebar."
                    ],
                    tip: "You can also drag and drop files directly onto the PandyDoc window.",
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "Set Up the PandyDoc Printer",
                    steps: [
                        "Click the **Printer Setup** button in the toolbar.",
                        "Follow the installation wizard to configure the virtual printer.",
                        "Once installed, you'll see **PandyDoc** in any app's print dialog.",
                        "Print any document to PandyDoc — it will be automatically captured and saved."
                    ],
                    tip: "You can also install the printer via Terminal: sudo ./Scripts/install_printer.sh",
                    warning: "Administrator access is required for printer installation."
                )
                
                WalkthroughSection(
                    title: "Check Out & Edit a Document",
                    steps: [
                        "Select a document in the sidebar or document list.",
                        "Click **Check Out & Edit** or right-click and select **Check Out**.",
                        "The document opens in its default application.",
                        "Make your changes and save them.",
                        "Return to PandyDoc and click **Check In** to save a new version."
                    ],
                    tip: "Changes are automatically tracked — each check-in creates a new version with a timestamp.",
                    warning: "Only one person can check out a document at a time."
                )
            }
            .padding()
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/Views/HelpTabs/GettingStartedTab.swift
git commit -m "feat: add Getting Started help tab content"
```

---

### Task 5: Create ManagingDocumentsTab Content

**Files:**
- Create: `Sources/DocManager/Views/HelpTabs/ManagingDocumentsTab.swift`

- [ ] **Step 1: Create Managing Documents tab content**

Create `Sources/DocManager/Views/HelpTabs/ManagingDocumentsTab.swift`:

```swift
import SwiftUI

struct ManagingDocumentsTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HelpSectionHeader(
                    title: "Managing Documents",
                    subtitle: "Import, edit, lock, export, and manage your documents."
                )
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    QuickRefCard(title: "Open a Document", description: "Open documents in their default application for viewing.", icon: "arrow.up.right.square") {}
                    QuickRefCard(title: "Lock a Document", description: "Prevent others from editing a document.", icon: "lock.fill") {}
                    QuickRefCard(title: "Export a Document", description: "Save a copy of a document outside PandyDoc.", icon: "square.and.arrow.up") {}
                    QuickRefCard(title: "Delete a Document", description: "Remove a document permanently.", icon: "trash.fill") {}
                }
                
                Divider()
                
                HelpSectionHeader(title: "Step-by-Step Guides", subtitle: "")
                
                WalkthroughSection(
                    title: "Open a Document",
                    steps: [
                        "Select a document in the list.",
                        "Right-click and select **Open**, or click the **Open** button in the toolbar.",
                        "The document opens in its default application."
                    ],
                    tip: "Locked documents can be viewed but not opened for editing.",
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "Lock and Unlock Documents",
                    steps: [
                        "Select a document and right-click.",
                        "Choose **Lock** to prevent others from editing it.",
                        "To unlock, right-click the locked document and select **Unlock**.",
                        "Only the person who locked the document can unlock it."
                    ],
                    tip: nil,
                    warning: "⚠️ Locked documents cannot be opened or edited by other users."
                )
                
                WalkthroughSection(
                    title: "Export a Document",
                    steps: [
                        "Right-click the document you want to export.",
                        "Select **Export...** from the context menu.",
                        "Choose a location and filename in the save panel.",
                        "Click **Save** to export a copy."
                    ],
                    tip: nil,
                    warning: "Template documents that are locked cannot be exported. Create a new document from the template instead."
                )
                
                WalkthroughSection(
                    title: "Delete a Document",
                    steps: [
                        "Right-click the document you want to delete.",
                        "Select **Delete** from the context menu.",
                        "Confirm the deletion in the alert."
                    ],
                    tip: nil,
                    warning: "⚠️ Deleted documents cannot be recovered. Make sure you have a backup if needed."
                )
            }
            .padding()
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/Views/HelpTabs/ManagingDocumentsTab.swift
git commit -m "feat: add Managing Documents help tab content"
```

---

### Task 6: Create OrganizingTab Content

**Files:**
- Create: `Sources/DocManager/Views/HelpTabs/OrganizingTab.swift`

- [ ] **Step 1: Create Organizing tab content**

Create `Sources/DocManager/Views/HelpTabs/OrganizingTab.swift`:

```swift
import SwiftUI

struct OrganizingTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HelpSectionHeader(
                    title: "Organizing Documents",
                    subtitle: "Use folders, tags, and search to keep your documents organized."
                )
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    QuickRefCard(title: "Create a Folder", description: "Group documents into folders.", icon: "folder.badge.plus") {}
                    QuickRefCard(title: "Add Tags", description: "Tag documents for easy filtering.", icon: "tag") {}
                    QuickRefCard(title: "Search Documents", description: "Find documents by name or content.", icon: "magnifyingglass") {}
                    QuickRefCard(title: "Flag Documents", description: "Mark important documents for quick access.", icon: "flag.fill") {}
                }
                
                Divider()
                
                HelpSectionHeader(title: "Step-by-Step Guides", subtitle: "")
                
                WalkthroughSection(
                    title: "Create and Manage Folders",
                    steps: [
                        "Click the **+** button next to **Folders** in the sidebar.",
                        "Enter a name for the folder and press Enter.",
                        "Drag documents into the folder to organize them.",
                        "Right-click a folder to **Rename**, **Archive**, or **Delete** it."
                    ],
                    tip: "You can create subfolders by right-clicking a folder and selecting **New Subfolder**.",
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "Add and Filter by Tags",
                    steps: [
                        "Select a document and look at the **Tags** section in the detail panel.",
                        "Type a tag name in the **Add tag...** field and press Enter.",
                        "Click a tag in the sidebar to filter documents by that tag.",
                        "Click **Clear filters** to remove tag filtering."
                    ],
                    tip: "Tags are case-insensitive and automatically capitalized.",
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "Search for Documents",
                    steps: [
                        "Click the **Search** field at the top of the document list.",
                        "Type a search term — results filter in real-time.",
                        "Press Enter to search, or click the **X** to clear."
                    ],
                    tip: "Search matches document names and tags.",
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "Flag Important Documents",
                    steps: [
                        "Right-click a document and select **Flag**.",
                        "Flagged documents appear in the **Flagged** section of the sidebar.",
                        "Click **Flagged** in the sidebar to view all flagged documents.",
                        "Right-click a flagged document and select **Unflag** to remove the flag."
                    ],
                    tip: nil,
                    warning: nil
                )
            }
            .padding()
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/Views/HelpTabs/OrganizingTab.swift
git commit -m "feat: add Organizing help tab content"
```

---

### Task 7: Create TemplatesVersionsTab Content

**Files:**
- Create: `Sources/DocManager/Views/HelpTabs/TemplatesVersionsTab.swift`

- [ ] **Step 1: Create Templates & Versions tab content**

Create `Sources/DocManager/Views/HelpTabs/TemplatesVersionsTab.swift`:

```swift
import SwiftUI

struct TemplatesVersionsTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HelpSectionHeader(
                    title: "Templates & Versions",
                    subtitle: "Create reusable templates and track document history."
                )
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    QuickRefCard(title: "Create a Template", description: "Save a document as a reusable template.", icon: "doc.badge.plus") {}
                    QuickRefCard(title: "New from Template", description: "Create a new document based on a template.", icon: "doc.on.doc") {}
                    QuickRefCard(title: "View Version History", description: "See all versions of a document.", icon: "clock.arrow.circlepath") {}
                    QuickRefCard(title: "Restore a Version", description: "Revert to a previous version.", icon: "arrow.uturn.backward") {}
                }
                
                Divider()
                
                HelpSectionHeader(title: "Step-by-Step Guides", subtitle: "")
                
                WalkthroughSection(
                    title: "Create a Template",
                    steps: [
                        "Right-click a document and select **Add to Templates**.",
                        "The document appears in the **Templates** section of the sidebar.",
                        "Templates are locked by default — they cannot be edited or deleted directly.",
                        "To use a template, right-click it and select **New from Template**."
                    ],
                    tip: "Templates are perfect for standard forms, contracts, or recurring document types.",
                    warning: "⚠️ Locked templates cannot be opened, edited, exported, or deleted."
                )
                
                WalkthroughSection(
                    title: "Create a New Document from a Template",
                    steps: [
                        "Navigate to the **Templates** section in the sidebar.",
                        "Right-click the template you want to use.",
                        "Select **New from Template**.",
                        "A copy of the template is created in **All Documents**."
                    ],
                    tip: nil,
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "View Version History",
                    steps: [
                        "Select a document in the list.",
                        "Right-click and select **Version History**, or click the **Versions** button.",
                        "A window shows all versions with timestamps, authors, and change notes.",
                        "Click **Restore** on any version to revert to that version."
                    ],
                    tip: "Each check-in automatically creates a new version.",
                    warning: "⚠️ Restoring a version creates a new version — it does not delete existing versions."
                )
            }
            .padding()
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/Views/HelpTabs/TemplatesVersionsTab.swift
git commit -m "feat: add Templates & Versions help tab content"
```

---

### Task 8: Create PrintingTab Content

**Files:**
- Create: `Sources/DocManager/Views/HelpTabs/PrintingTab.swift`

- [ ] **Step 1: Create Printing tab content**

Create `Sources/DocManager/Views/HelpTabs/PrintingTab.swift`:

```swift
import SwiftUI

struct PrintingTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HelpSectionHeader(
                    title: "Printing to PandyDoc",
                    subtitle: "Capture PDFs from any application using the PandyDoc virtual printer."
                )
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    QuickRefCard(title: "Install Printer", description: "Set up the PandyDoc virtual printer.", icon: "printer.fill") {}
                    QuickRefCard(title: "Print to PandyDoc", description: "Capture PDFs from any app.", icon: "doc.richtext") {}
                    QuickRefCard(title: "View Incoming Documents", description: "See recently printed documents.", icon: "tray.fill") {}
                    QuickRefCard(title: "Troubleshoot Printer", description: "Fix common printer issues.", icon: "wrench") {}
                }
                
                Divider()
                
                HelpSectionHeader(title: "Step-by-Step Guides", subtitle: "")
                
                WalkthroughSection(
                    title: "Install the PandyDoc Printer",
                    steps: [
                        "Click the **Printer Setup** button in the toolbar.",
                        "Follow the installation wizard.",
                        "Enter your administrator password when prompted.",
                        "Once installed, **PandyDoc** appears in your system printers."
                    ],
                    tip: "You can also install via Terminal: sudo ./Scripts/install_printer.sh",
                    warning: "Administrator access is required."
                )
                
                WalkthroughSection(
                    title: "Print a Document to PandyDoc",
                    steps: [
                        "In any application, press Cmd+P to open the Print dialog.",
                        "Select **PandyDoc** from the printer dropdown.",
                        "Click **Print**.",
                        "The PDF is automatically captured and saved to PandyDoc.",
                        "A notification confirms the document was received."
                    ],
                    tip: "You can also use the PDF dropdown in the print dialog and select **Save to PandyDoc**.",
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "View Incoming Documents",
                    steps: [
                        "Click **Inbox** in the sidebar to see recently printed documents.",
                        "The inbox count shows how many unprocessed documents are waiting.",
                        "Documents are automatically imported into PandyDoc."
                    ],
                    tip: nil,
                    warning: nil
                )
            }
            .padding()
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/Views/HelpTabs/PrintingTab.swift
git commit -m "feat: add Printing help tab content"
```

---

### Task 9: Create AdvancedTab Content

**Files:**
- Create: `Sources/DocManager/Views/HelpTabs/AdvancedTab.swift`

- [ ] **Step 1: Create Advanced tab content**

Create `Sources/DocManager/Views/HelpTabs/AdvancedTab.swift`:

```swift
import SwiftUI

struct AdvancedTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HelpSectionHeader(
                    title: "Advanced Features",
                    subtitle: "Settings, backups, file watching, keyboard shortcuts, and troubleshooting."
                )
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    QuickRefCard(title: "Settings", description: "Configure PandyDoc preferences.", icon: "gearshape") {}
                    QuickRefCard(title: "Keyboard Shortcuts", description: "Quick reference for all shortcuts.", icon: "command") {}
                    QuickRefCard(title: "iCloud Backup", description: "Back up your database to iCloud.", icon: "icloud") {}
                    QuickRefCard(title: "Troubleshooting", description: "Fix common issues.", icon: "wrench.and.screwdriver") {}
                }
                
                Divider()
                
                HelpSectionHeader(title: "Step-by-Step Guides", subtitle: "")
                
                WalkthroughSection(
                    title: "Keyboard Shortcuts",
                    steps: [
                        "**Cmd+I** — Import Document",
                        "**Cmd+Option+I** — Import Folder",
                        "**Cmd+Shift+S** — Check In Document",
                        "**Cmd+?** — Open Help",
                        "**Cmd+1** — Show All Documents",
                        "**Cmd+2** — Show Templates",
                        "**Cmd+3** — Show Inbox",
                        "**Cmd+4** — Show Flagged",
                        "**Cmd+Option+0** — Show Sidebar"
                    ],
                    tip: nil,
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "iCloud Backup",
                    steps: [
                        "Open **Settings** from the PandyDoc menu.",
                        "Navigate to the **Backup** section.",
                        "Click **Backup to iCloud Drive**.",
                        "Choose a location and confirm."
                    ],
                    tip: "Regular backups protect your document database.",
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "File Watching",
                    steps: [
                        "PandyDoc automatically monitors open documents for changes.",
                        "When you edit a checked-out document externally, PandyDoc detects the change.",
                        "The document status updates automatically when you return to PandyDoc."
                    ],
                    tip: nil,
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "Troubleshooting",
                    steps: [
                        "**Printer not working?** Reinstall via Printer Setup or Terminal.",
                        "**Documents not appearing?** Click the **Refresh** button in the toolbar.",
                        "**Can't check out a document?** Check if it's locked by another user.",
                        "**App not launching?** Try rebuilding from Xcode or reinstalling the DMG."
                    ],
                    tip: "If issues persist, check the Console app for PandyDoc logs.",
                    warning: nil
                )
            }
            .padding()
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/Views/HelpTabs/AdvancedTab.swift
git commit -m "feat: add Advanced help tab content"
```

---

### Task 10: Integrate HelpView into ContentView and DocManagerApp

**Files:**
- Modify: `Sources/DocManager/Views/ContentView.swift`
- Modify: `Sources/DocManager/DocManagerApp.swift`

- [ ] **Step 1: Add HelpView sheet state to ContentView**

In `ContentView.swift`, add a state variable for the help sheet and update the notification handlers. Find the existing help-related state variables (around line 17-19):

```swift
    @State private var showHelpSheet = false
    @State private var showGettingStartedSheet = false
    @State private var showShortcutsSheet = false
```

Replace with:

```swift
    @State private var showHelp = false
    @State private var helpInitialTab: HelpTab? = nil
```

- [ ] **Step 2: Replace old help sheet references with HelpView**

Find the old sheet modifiers (around lines 107-115):

```swift
        .sheet(isPresented: $showHelpSheet) {
            HelpSheetView()
        }
        .sheet(isPresented: $showGettingStartedSheet) {
            GettingStartedSheetView()
        }
        .sheet(isPresented: $showShortcutsSheet) {
            KeyboardShortcutsSheetView()
        }
```

Replace with:

```swift
        .sheet(isPresented: $showHelp) {
            HelpView(initialTab: helpInitialTab)
        }
```

- [ ] **Step 3: Update notification handlers in ContentView**

Find the notification observers (around lines 121-129):

```swift
            NotificationCenter.default.addObserver(
                forName: .showHelp, object: nil, queue: .main
            ) { _ in showHelpSheet = true }
            NotificationCenter.default.addObserver(
                forName: .showGettingStarted, object: nil, queue: .main
            ) { _ in showGettingStartedSheet = true }
            NotificationCenter.default.addObserver(
                forName: .showShortcuts, object: nil, queue: .main
            ) { _ in showShortcutsSheet = true }
```

Replace with:

```swift
            NotificationCenter.default.addObserver(
                forName: .showHelp, object: nil, queue: .main
            ) { _ in
                helpInitialTab = nil
                showHelp = true
            }
            NotificationCenter.default.addObserver(
                forName: .showHelpWithTab, object: nil, queue: .main
            ) { notification in
                if let tab = notification.userInfo?["tab"] as? HelpTab {
                    helpInitialTab = tab
                }
                showHelp = true
            }
```

- [ ] **Step 4: Update DocManagerApp menu commands**

In `DocManagerApp.swift`, update the help CommandGroup (around lines 81-102):

```swift
            CommandGroup(replacing: .help) {
                Button("PandyDoc Help") {
                    NotificationCenter.default.post(name: .showHelpWithTab, object: nil, userInfo: ["tab": HelpTab.gettingStarted])
                }
                .keyboardShortcut("?", modifiers: [.command])

                Divider()

                Button("Getting Started") {
                    NotificationCenter.default.post(name: .showHelpWithTab, object: nil, userInfo: ["tab": HelpTab.gettingStarted])
                }

                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .showHelpWithTab, object: nil, userInfo: ["tab": HelpTab.advanced])
                }

                Divider()

                Button("About PandyDoc") {
                    showAbout = true
                }
            }
```

- [ ] **Step 5: Commit**

```bash
git add Sources/DocManager/Views/ContentView.swift Sources/DocManager/DocManagerApp.swift
git commit -m "feat: integrate HelpView into ContentView and DocManagerApp"
```

---

### Task 11: Build and Verify

**Files:**
- No file changes

- [ ] **Step 1: Build the project**

```bash
swift build
```

Expected: Build succeeds with no errors.

- [ ] **Step 2: Verify all help tabs compile**

```bash
ls -la Sources/DocManager/Views/HelpTabs/
```

Expected: All 6 tab files present.

- [ ] **Step 3: Final commit (if any changes)**

```bash
git status
```

If there are uncommitted changes, commit them.
