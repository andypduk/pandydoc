# PandyDoc UI Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh PandyDoc's UI to a modern Apple-native design using macOS Sonoma/Ventura patterns: vibrancy materials, refined typography, file-type colored icons, card-based document rows, and pill-shaped action buttons, while keeping all core functionality unchanged.

**Architecture:** Create a `DesignTokens.swift` file with all color, spacing, and typography constants, then modify each existing view file in place to use these tokens. No new view files needed — purely visual restyling.

**Tech Stack:** SwiftUI, existing Document/ViewModel models, NSColor materials for vibrancy

---

### Task 1: Create DesignTokens.swift

**Files:**
- Create: `Sources/DocManager/Utilities/DesignTokens.swift`

- [ ] **Step 1: Create DesignTokens.swift with all visual constants**

```swift
// Sources/DocManager/Utilities/DesignTokens.swift
import SwiftUI

enum DesignTokens {
    enum Colors {
        static let statusAvailable = Color(red: 0.20, green: 0.78, blue: 0.35)  // #34c759
        static let statusCheckedOut = Color(red: 0.00, green: 0.48, blue: 1.00) // #007aff
        static let statusLocked = Color(red: 1.00, green: 0.23, blue: 0.19)     // #ff3b30
        static let selectionBackground = Color.accentColor.opacity(0.08)
        static let separatorThin = Color.black.opacity(0.08)
        static let cardBackground = Color(NSColor.windowBackgroundColor)
        static let tagChipBackground = Color.accentColor.opacity(0.1)
        static let badgeBackground = Color.accentColor.opacity(0.2)
    }
    
    enum FileTypeColor {
        static func gradient(for type: DocumentType) -> [Color] {
            switch type {
            case .pdf: return [Color(red: 1.00, green: 0.23, blue: 0.19), Color(red: 1.00, green: 0.58, blue: 0.00)]
            case .docx, .pages: return [Color(red: 0.35, green: 0.34, blue: 0.84), Color(red: 0.69, green: 0.32, blue: 0.87)]
            case .xlsx, .numbers: return [Color(red: 0.00, green: 0.48, blue: 1.00), Color(red: 0.35, green: 0.34, blue: 0.84)]
            case .pptx, .key: return [Color(red: 1.00, green: 0.58, blue: 0.00), Color(red: 1.00, green: 0.80, blue: 0.00)]
            case .txt, .rtf: return [Color(red: 0.56, green: 0.56, blue: 0.58), Color(red: 0.39, green: 0.39, blue: 0.40)]
            case .other: return [Color(red: 0.56, green: 0.56, blue: 0.58), Color(red: 0.39, green: 0.39, blue: 0.40)]
            }
        }
        
        static func icon(for type: DocumentType) -> String {
            switch type {
            case .pdf: return "doc.richtext"
            case .docx, .pages: return "doc.text"
            case .xlsx, .numbers: return "tablecells"
            case .pptx, .key: return "play.rectangle.fill"
            case .txt: return "doc.plaintext"
            case .rtf: return "doc.richtext"
            case .other: return "doc"
            }
        }
        
        static func label(for type: DocumentType) -> String {
            switch type {
            case .pdf: return "PDF"
            case .docx, .pages: return "DOC"
            case .xlsx, .numbers: return "XLS"
            case .pptx, .key: return "PPT"
            case .txt, .rtf: return "TXT"
            case .other: return "FILE"
            }
        }
    }
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }
    
    enum Corner {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
    }
    
    enum Typography {
        static func titleStyle() -> Font {
            Font.title3.weight(.semibold)
        }
        static func bodyStyle() -> Font {
            Font.body.weight(.regular)
        }
        static func metadataStyle() -> Font {
            Font.caption.weight(.medium)
        }
        static func labelStyle() -> Font {
            Font.caption2.weight(.semibold)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/Utilities/DesignTokens.swift
git commit -m "feat: add DesignTokens for UI refresh"
```

---

### Task 2: Refresh DocumentRowView

**Files:**
- Modify: `Sources/DocManager/Views/DocumentRowView.swift`

- [ ] **Step 1: Replace documentIcon with gradient file-type icon**

Replace the entire `documentIcon` computed property (lines 88-125):

```swift
    private var documentIcon: some View {
        let colors = DesignTokens.FileTypeColor.gradient(for: document.documentType)
        let iconName = DesignTokens.FileTypeColor.icon(for: document.documentType)
        let label = DesignTokens.FileTypeColor.label(for: document.documentType)
        
        return ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Corner.md)
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 40)
                .shadow(color: colors[0].opacity(0.3), radius: 4, x: 0, y: 2)
            
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
```

- [ ] **Step 2: Replace body with two-line card layout**

Replace the entire `body` property (lines 8-86):

```swift
    var body: some View {
        HStack(spacing: DesignTokens.sm) {
            documentIcon
            
            VStack(alignment: .leading, spacing: DesignTokens.xs) {
                Text(document.name)
                    .font(DesignTokens.Typography.bodyStyle())
                    .lineLimit(1)
                
                HStack(spacing: DesignTokens.xs) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: statusColor.opacity(0.4), radius: document.isCheckedOut ? 3 : 0)
                    
                    Text(statusText)
                        .font(DesignTokens.Typography.metadataStyle())
                        .foregroundColor(.secondary)
                    
                    Text("·")
                        .font(DesignTokens.Typography.metadataStyle())
                        .foregroundColor(.secondary)
                    
                    Text("v\(document.currentVersion)")
                        .font(DesignTokens.Typography.metadataStyle())
                        .foregroundColor(.secondary)
                }

                if viewModel.isShowingAllDocuments,
                   let folderName = viewModel.folderName(for: document) {
                    HStack(spacing: 2) {
                        Image(systemName: "folder")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                        Text(folderName)
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            
            Spacer()
            
            if document.flagged {
                Image(systemName: "flag.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if document.isLocked {
                Image(systemName: "lock.fill")
                    .foregroundColor(DesignTokens.Colors.statusLocked)
                    .font(.caption)
            }

            if document.protected {
                Image(systemName: "shield.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
        .padding(.vertical, DesignTokens.sm)
        .padding(.horizontal, DesignTokens.sm)
        .contentShape(Rectangle())
        .onDrag {
            let provider = NSItemProvider()
            provider.suggestedName = document.fileName
            provider.registerFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier, fileOptions: [], visibility: .all) { completion in
                let fileURL = URL(fileURLWithPath: document.filePath)
                completion(fileURL, true, nil)
                return nil
            }
            provider.registerDataRepresentation(forTypeIdentifier: "public.utf8-plain-text", visibility: .ownProcess) { completion in
                let data = document.id.uuidString.data(using: .utf8) ?? Data()
                completion(data, nil)
                return nil
            }
            return provider
        }
        .contextMenu {
            documentContextMenu
        }
    }
    
    private var statusColor: Color {
        switch document.status {
        case .available: return DesignTokens.Colors.statusAvailable
        case .checkedOut: return DesignTokens.Colors.statusCheckedOut
        case .locked: return DesignTokens.Colors.statusLocked
        }
    }
```

- [ ] **Step 3: Update statusText to remove checked-out icon (now shown via status dot)**

Replace the `statusText` property (lines 127-137):

```swift
    private var statusText: String {
        switch document.status {
        case .available: return "Available"
        case .checkedOut:
            if document.checkedOutBy == NSFullUserName() {
                return "Checked out by you"
            }
            return "Checked out"
        case .locked: return "Locked"
        }
    }
```

- [ ] **Step 4: Verify build and commit**

Run: `swift build 2>&1`
Expected: Build complete

```bash
git add Sources/DocManager/Views/DocumentRowView.swift
git commit -m "feat: refresh DocumentRowView with gradient icons and two-line layout"
```

---

### Task 3: Refresh DocumentQuickView

**Files:**
- Modify: `Sources/DocManager/Views/DocumentQuickView.swift`

- [ ] **Step 1: Add header section above toolbar**

Add a new `headerSection` computed property after the `statusBar` property (around line 261):

```swift
    private var headerSection: some View {
        HStack(spacing: DesignTokens.md) {
            let colors = DesignTokens.FileTypeColor.gradient(for: document.documentType)
            let label = DesignTokens.FileTypeColor.label(for: document.documentType)
            
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Corner.lg)
                    .fill(
                        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 40, height: 50)
                    .shadow(color: colors[0].opacity(0.3), radius: 6, x: 0, y: 3)
                
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: DesignTokens.xs) {
                Text(document.name)
                    .font(DesignTokens.Typography.titleStyle())
                    .lineLimit(1)
                
                HStack(spacing: DesignTokens.xs) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(document.statusText)
                        .font(DesignTokens.Typography.metadataStyle())
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.lg)
        .padding(.vertical, DesignTokens.md)
    }
```

- [ ] **Step 2: Replace toolbar with pill-shaped buttons**

Replace the `toolbar` property (lines 119-183):

```swift
    private var toolbar: some View {
        HStack(spacing: DesignTokens.sm) {
            if pdfDocument != nil || previewImage != nil {
                pillButton(icon: "plus.magnifyingglass", action: zoomIn, disabled: zoomLevel >= 3.0, help: "Zoom In")
                pillButton(icon: "minus.magnifyingglass", action: zoomOut, disabled: zoomLevel <= 0.25, help: "Zoom Out")
                pillButton(icon: "1.magnifyingglass", action: { zoomLevel = 1.0 }, disabled: zoomLevel == 1.0, help: "Actual Size")
            }

            Spacer()

            if pdfDocument != nil && totalPages > 1 {
                HStack(spacing: DesignTokens.xs) {
                    pillButton(icon: "chevron.left", action: { if currentPage > 1 { currentPage -= 1 } }, disabled: currentPage <= 1)
                    Text("Page \(currentPage) of \(totalPages)")
                        .font(.caption)
                        .monospacedDigit()
                    pillButton(icon: "chevron.right", action: { if currentPage < totalPages { currentPage += 1 } }, disabled: currentPage >= totalPages)
                }
            }

            Spacer()

            if !isQuickLookable && !isPDF {
                actionPill(label: "Convert to PDF", icon: "doc.richtext", action: convertToPDF, disabled: isConverting)
            }

            actionPill(label: "Open", icon: "arrow.up.right.square", action: {
                NSWorkspace.shared.open(URL(fileURLWithPath: document.filePath))
            }, disabled: document.isLocked)
        }
        .padding(.horizontal, DesignTokens.md)
        .padding(.vertical, DesignTokens.sm)
    }
    
    private func pillButton(icon: String, action: @escaping () -> Void, disabled: Bool = false, help: String? = nil) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 28, height: 28)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(DesignTokens.Corner.sm)
        }
        .disabled(disabled)
        .buttonStyle(.plain)
        .help(help ?? "")
    }
    
    private func actionPill(label: String, icon: String, action: @escaping () -> Void, disabled: Bool = false) -> some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, DesignTokens.sm)
            .padding(.vertical, DesignTokens.xs)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(DesignTokens.Corner.lg)
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }
```

- [ ] **Step 3: Refresh tagSection with refined chips**

Replace the `tagSection` property (lines 80-117):

```swift
    private var tagSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.sm) {
            Text("Tags")
                .font(DesignTokens.Typography.labelStyle())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            if !document.tags.isEmpty {
                FlowLayout(spacing: DesignTokens.xs) {
                    ForEach(document.tags, id: \.self) { tag in
                        RefinedTagChip(tag: tag) {
                            viewModel.removeTag(from: document, tag: tag)
                        }
                    }
                }
            }
            
            HStack(spacing: DesignTokens.xs) {
                Image(systemName: "tag")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Add tag...", text: $newTagText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .onSubmit {
                        if !newTagText.isEmpty {
                            viewModel.addTag(to: document, tag: newTagText)
                            newTagText = ""
                        }
                    }
            }
            .padding(DesignTokens.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Corner.md)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundColor(Color.black.opacity(0.15))
            )
        }
        .padding(.horizontal, DesignTokens.lg)
        .padding(.vertical, DesignTokens.sm)
    }
```

- [ ] **Step 4: Replace TagChip with RefinedTagChip**

Replace the `TagChip` struct (lines 403-423):

```swift
struct RefinedTagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.xs) {
            Text(tag)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 9))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, DesignTokens.sm)
        .padding(.vertical, DesignTokens.xs)
        .background(DesignTokens.Colors.tagChipBackground)
        .cornerRadius(DesignTokens.Corner.xl)
    }
}
```

- [ ] **Step 5: Refresh documentPreview container with card styling**

Replace the `documentPreview` property (lines 185-223):

```swift
    private var documentPreview: some View {
        Group {
            if isConverting {
                VStack(spacing: DesignTokens.sm) {
                    ProgressView()
                    Text("Generating preview...")
                        .font(DesignTokens.Typography.metadataStyle())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let pdf = pdfDocument {
                PDFKitView(document: pdf, zoomLevel: zoomLevel, currentPage: $currentPage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let image = previewImage {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .scaleEffect(zoomLevel, anchor: .center)
                        .frame(minWidth: image.size.width, minHeight: image.size.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let url = previewURL {
                QuickLookView(fileURL: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: DesignTokens.lg) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Preview not available")
                        .font(DesignTokens.Typography.bodyStyle())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(DesignTokens.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Corner.lg)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, DesignTokens.lg)
        .padding(.vertical, DesignTokens.sm)
    }
```

- [ ] **Step 6: Add statusColor helper and update statusBar**

Add after the `statusBar` property:

```swift
    private var statusColor: Color {
        switch document.status {
        case .available: return DesignTokens.Colors.statusAvailable
        case .checkedOut: return DesignTokens.Colors.statusCheckedOut
        case .locked: return DesignTokens.Colors.statusLocked
        }
    }
```

Replace the `statusBar` property (lines 225-261):

```swift
    private var statusBar: some View {
        HStack {
            Text(document.name)
                .font(DesignTokens.Typography.metadataStyle())
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(formatFileSize(document.fileSize))
                .font(DesignTokens.Typography.metadataStyle())
                .foregroundColor(.secondary)

            Text("·")
                .font(DesignTokens.Typography.metadataStyle())
                .foregroundColor(.secondary)

            Text("v\(document.currentVersion)")
                .font(DesignTokens.Typography.metadataStyle())
                .foregroundColor(.secondary)

            Text("·")
                .font(DesignTokens.Typography.metadataStyle())
                .foregroundColor(.secondary)

            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(document.status.rawValue.capitalized)
                .font(DesignTokens.Typography.metadataStyle())
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, DesignTokens.lg)
        .padding(.vertical, DesignTokens.sm)
        .background(Color(NSColor.controlBackgroundColor))
    }
```

- [ ] **Step 7: Update body to include headerSection**

Replace the body (lines 49-76):

```swift
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            toolbar
            Divider()
            tagSection
            Divider()
            documentPreview
            Divider()
            statusBar
        }
        .onAppear { loadDocument() }
        .onChange(of: viewModel.selectedDocument?.id) { _, _ in loadDocument() }
        .onChange(of: viewModel.documentRefreshToken) { _, _ in loadDocument() }
        .alert("Conversion Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
```

- [ ] **Step 8: Verify build and commit**

Run: `swift build 2>&1`
Expected: Build complete

```bash
git add Sources/DocManager/Views/DocumentQuickView.swift
git commit -m "feat: refresh DocumentQuickView with header, pill buttons, refined tags, card preview"
```

---

### Task 4: Refresh ContentView Sidebar

**Files:**
- Modify: `Sources/DocManager/Views/ContentView.swift`

- [ ] **Step 1: Replace appBranding with refined header**

Find the `appBranding` computed property and replace it:

```swift
    private var appBranding: some View {
        HStack(spacing: DesignTokens.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Corner.md)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.2, blue: 0.2), Color(red: 0.33, green: 0.33, blue: 0.33)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)
                
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            
            Text("PandyDoc")
                .font(.title3.weight(.bold))
                .tracking(-0.2)
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.md)
        .padding(.vertical, DesignTokens.sm)
    }
```

- [ ] **Step 2: Refine sidebar items with section headers and badges**

Replace the entire sidebar `List` section (lines 209-328). Replace the Section with Library items:

```swift
            List(selection: $sidebarSelection) {
            Section {
                Text("Library")
                    .font(DesignTokens.Typography.labelStyle())
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, DesignTokens.md)
                    .padding(.bottom, DesignTokens.xs)
                
                sidebarItem(icon: "tray.fill", label: "Inbox", tag: SidebarItem.inbox,
                    badge: viewModel.inboxDocumentCount > 0 ? "\(viewModel.inboxDocumentCount)" : nil,
                    badgeColor: .orange,
                    isSelected: viewModel.isShowingInbox,
                    onDrop: { handleDropToFolder(providers: $0, targetFolderID: viewModel.getInboxFolderID()) })
                
                sidebarItem(icon: "flag.fill", label: "Flagged", tag: SidebarItem.flagged,
                    badge: viewModel.flaggedDocumentCount > 0 ? "\(viewModel.flaggedDocumentCount)" : nil,
                    badgeColor: .red,
                    isSelected: viewModel.isShowingFlagged)
                
                sidebarItem(icon: "house.fill", label: "All Documents", tag: SidebarItem.allDocuments,
                    badge: viewModel.checkedOutCount > 0 ? "\(viewModel.checkedOutCount)" : nil,
                    badgeColor: .blue,
                    isSelected: viewModel.isShowingAllDocuments,
                    onDrop: { handleDropToFolder(providers: $0, targetFolderID: nil) })
                
                if viewModel.isShowingAllDocuments {
                    sidebarItem(icon: "doc.on.doc.fill", label: "Templates", tag: SidebarItem.templates,
                        isSelected: viewModel.isShowingTemplates)
                }
            }
```

- [ ] **Step 3: Add sidebarItem helper**

Add after the `appBranding` property:

```swift
    private func sidebarItem(
        icon: String,
        label: String,
        tag: SidebarItem,
        badge: String? = nil,
        badgeColor: Color = .accentColor,
        isSelected: Bool = false,
        onDrop: (([NSItemProvider]) -> Void)? = nil
    ) -> some View {
        HStack(spacing: DesignTokens.sm) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(label)
                .font(.body)
                .fontWeight(isSelected ? .medium : .regular)
            Spacer()
            if let badge {
                Text(badge)
                    .font(.caption.weight(.medium))
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, DesignTokens.xs)
                    .padding(.vertical, 1)
                    .background(badgeColor.opacity(0.15))
                    .cornerRadius(DesignTokens.Corner.sm)
            }
        }
        .tag(tag)
        .padding(.horizontal, DesignTokens.sm)
        .padding(.vertical, DesignTokens.xs)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            onDrop?(providers)
            return true
        }
        .contextMenu {
            Button(action: { showImportSheet = true }) {
                Label("Import Document...", systemImage: "square.and.arrow.down")
            }
            Divider()
            Button(action: { viewModel.refreshDocuments() }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }
```

- [ ] **Step 4: Verify build and commit**

Run: `swift build 2>&1`
Expected: Build complete

```bash
git add Sources/DocManager/Views/ContentView.swift
git commit -m "feat: refresh sidebar with section headers, refined badges, and helper"
```

---

### Task 5: Refresh SettingsView API Tab

**Files:**
- Modify: `Sources/DocManager/Views/SettingsView.swift`

- [ ] **Step 1: Replace apiSettings with Form-based layout**

Replace the entire `apiSettings` property (lines 236-290):

```swift
    var apiSettings: some View {
        Form {
            Section("API Key") {
                HStack {
                    Text(showApiKey ? APIKeyManager.shared.apiKey : String(repeating: "•", count: 64))
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button(showApiKey ? "Hide" : "Show") { showApiKey.toggle() }
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(APIKeyManager.shared.apiKey, forType: .string)
                    }
                }
                
                Button("Regenerate Key", role: .destructive) { showRegenerateAlert = true }
                    .alert("Regenerate API Key?", isPresented: $showRegenerateAlert) {
                        Button("Regenerate", role: .destructive) { _ = APIKeyManager.shared.regenerateKey(); showApiKey = false }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("The current key will stop working immediately.")
                    }
            }
            
            Section("Server") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(APIServer.shared.isRunning ? "Running" : "Stopped")
                        .foregroundColor(APIServer.shared.isRunning ? .green : .red)
                    Button(APIServer.shared.isRunning ? "Stop" : "Start") {
                        Task { @MainActor in
                            if APIServer.shared.isRunning {
                                await APIServer.shared.stop()
                            } else {
                                try? await APIServer.shared.start()
                            }
                        }
                    }
                }
                
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("Port", value: $apiPort, formatter: NumberFormatter())
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: apiPort) { UserDefaults.standard.set(apiPort, forKey: "apiPort") }
                }
            }
        }
        .formStyle(.grouped)
    }
```

- [ ] **Step 2: Verify build and commit**

Run: `swift build 2>&1`
Expected: Build complete

```bash
git add Sources/DocManager/Views/SettingsView.swift
git commit -m "feat: refine API tab settings to match grouped form style"
```

---

### Task 6: Final Build Verification

**Files:**
- All modified files

- [ ] **Step 1: Full build verification**

Run: `swift build 2>&1`
Expected: Build complete with no new errors (pre-existing Sendable warnings acceptable)

- [ ] **Step 2: Verify no functionality regressions**

Check that all existing features still compile:
- Document CRUD operations
- Check-in/out flow
- Version history
- Folder management
- Templates
- Search and filtering
- REST API endpoints
- Help system

All should compile without errors since we only changed visual styling.
