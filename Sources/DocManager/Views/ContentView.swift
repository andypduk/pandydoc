import SwiftUI

enum SidebarItem: Hashable {
    case flagged
    case inbox
    case allDocuments
    case templates
    case folder(Folder)
}

struct ContentView: View {
    @StateObject private var viewModel = DocumentListViewModel()
    @State private var showImportSheet = false
    @State private var showPrinterSetup = false
    @State private var isCreatingFolder = false
    @State private var sidebarSelection: SidebarItem? = .allDocuments
    @State private var showHelp = false
    @State private var helpInitialTab: HelpTab? = nil
    @State private var expandedFolders: Set<UUID> = []

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } content: {
            VStack(spacing: 0) {
                statsBar
                Divider()
                documentList
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 350)
        } detail: {
            detailView
                .navigationSplitViewColumnWidth(min: 320, ideal: 450)
        }
        .frame(minWidth: 900, minHeight: 600)
        .toolbar { toolbarContent }
        .navigationTitle("PandyDoc")
        .fileImporter(
            isPresented: $showImportSheet,
            allowedContentTypes: [.pdf, .data, .folder],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if isDirectory {
                        viewModel.importFolder(folderURL: url)
                    } else {
                        viewModel.importDocument(fileURL: url)
                    }
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .alert("Folder Access Required", isPresented: .init(
            get: { viewModel.pendingImportURL != nil },
            set: { if !$0 { viewModel.pendingImportURL = nil } }
        )) {
            Button("Grant Access") {
                if let url = viewModel.pendingImportURL {
                    let folderURL = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
                    viewModel.grantAccessAndImport(folderURL: folderURL)
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.pendingImportURL = nil
            }
        } message: {
            Text("PandyDoc needs access to this folder to import the item.")
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $viewModel.showCheckInSheet) {
            CheckInSheetView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showVersionHistory) {
            VersionHistoryView(viewModel: viewModel)
        }
        .sheet(isPresented: $showPrinterSetup) {
            PrinterSetupSheet()
        }
        .alert("Rename Document", isPresented: $viewModel.showRenameAlert) {
            TextField("Name", text: $viewModel.renameText)
            Button("Cancel", role: .cancel) { viewModel.showRenameAlert = false }
            Button("Rename") { viewModel.performRename() }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $viewModel.showArchiveSheet) {
            ArchiveSheetView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showFolderMoveSheet) {
            FolderMoveSheetView(viewModel: viewModel)
        }
        .sheet(isPresented: $showHelp) {
            HelpView(initialTab: helpInitialTab)
        }
        .sheet(isPresented: $viewModel.showTagCloud) {
            TagCloudView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.loadInitialData()
            NotificationCenter.default.addObserver(
                forName: .showPrinterSetup, object: nil, queue: .main
            ) { _ in showPrinterSetup = true }
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
            NotificationCenter.default.addObserver(
                forName: .navigateToAllDocuments, object: nil, queue: .main
            ) { [weak viewModel] _ in Task { @MainActor in viewModel?.navigateToRoot() } }
            NotificationCenter.default.addObserver(
                forName: .navigateToTemplates, object: nil, queue: .main
            ) { [weak viewModel] _ in Task { @MainActor in viewModel?.navigateToTemplates() } }
            NotificationCenter.default.addObserver(
                forName: .navigateToInbox, object: nil, queue: .main
            ) { [weak viewModel] _ in Task { @MainActor in viewModel?.navigateToInbox() } }
            NotificationCenter.default.addObserver(
                forName: .navigateToFlagged, object: nil, queue: .main
            ) { [weak viewModel] _ in Task { @MainActor in viewModel?.navigateToFlagged() } }
        }
        .onChange(of: sidebarSelection) { _, newSelection in
            switch newSelection {
            case .flagged: viewModel.navigateToFlagged()
            case .inbox: viewModel.navigateToInbox()
            case .allDocuments, .none: viewModel.navigateToRoot()
            case .templates: viewModel.navigateToTemplates()
            case .folder(let folder): viewModel.navigateToFolder(folder)
            }
        }
        .onChange(of: viewModel.currentFolder) { _, _ in
            if let folder = viewModel.currentFolder {
                sidebarSelection = .folder(folder)
            } else if viewModel.isShowingFlagged {
                sidebarSelection = .flagged
            } else if viewModel.isShowingInbox {
                sidebarSelection = .inbox
            } else if viewModel.isShowingTemplates {
                sidebarSelection = .templates
            } else {
                sidebarSelection = .allDocuments
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: { viewModel.navigateBack() }) {
                Image(systemName: "chevron.left")
            }
            .disabled(!viewModel.canNavigateBack)
            .help("Back")
            Button(action: { viewModel.navigateForward() }) {
                Image(systemName: "chevron.right")
            }
            .disabled(!viewModel.canNavigateForward)
            .help("Forward")
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { showImportSheet = true }) {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .help("Import documents or folders")
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { showPrinterSetup = true }) {
                Label("Printer Setup", systemImage: "printer")
            }
            .help("Setup PandyDoc printer")
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { viewModel.refreshDocuments() }) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { startCreateFolder(parentID: nil) }) {
                Image(systemName: "folder.badge.plus")
            }
            .help("New Folder")
        }
    }

    private var sidebar: some View {
        ScrollViewReader { _ in
            ScrollView {
                VStack(spacing: 8) {
                    appBranding
                    sidebarSection("Library") {
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
                        
                        sidebarItem(icon: "doc.on.doc.fill", label: "Templates", tag: SidebarItem.templates,
                            isSelected: viewModel.isShowingTemplates)
                    }
                    
                    sidebarSection("Folders") {
                        FolderTreeView(nodes: viewModel.folderTree, selection: $sidebarSelection, expandedFolders: $expandedFolders,
                            onDropFile: { folder, providers in
                                handleMixedDrop(providers: providers, folder: folder)
                            },
                            onDeleteFolder: { folder in
                                viewModel.deleteFolder(folder)
                            },
                            onRenameFolder: { folder in
                                viewModel.startRenameFolder(folder)
                            },
                            onArchiveFolder: { folder in
                                viewModel.archiveFolder(folder)
                            },
                            onNewSubfolder: { folder in
                                startCreateFolder(parentID: folder.id)
                            },
                            onToggleProtection: { folder in
                                viewModel.toggleFolderProtection(folder)
                            },
                            onMoveFolder: { folder in
                                viewModel.moveFolder(folder)
                            },
                            isCreatingFolder: $isCreatingFolder,
                            newFolderName: $viewModel.newFolderName,
                            newFolderParentID: $viewModel.newFolderParentID,
                            folderFieldFocused: $folderFieldFocused,
                            onCreateFolder: { name, parentID in
                                viewModel.createFolder(name: name, parentID: parentID)
                                if let parentID {
                                    expandedFolders.insert(parentID)
                                }
                                viewModel.newFolderName = ""
                                isCreatingFolder = false
                                viewModel.newFolderParentID = nil
                            },
                            onCancelCreate: {
                                isCreatingFolder = false
                                viewModel.newFolderName = ""
                                viewModel.newFolderParentID = nil
                            },
                            showFolderRenameAlert: $viewModel.showFolderRenameAlert,
                            folderRenameText: $viewModel.folderRenameText,
                            folderToRename: $viewModel.folderToRename,
                            showDeleteFolderConfirmation: $viewModel.showDeleteFolderConfirmation,
                            folderToDelete: $viewModel.folderToDelete,
                            onPerformFolderRename: { viewModel.performFolderRename() },
                            onConfirmDeleteFolder: { viewModel.confirmDeleteFolder() }
                        )
                    }
                    
                    if !viewModel.allTags.isEmpty {
                        sidebarSection("Tags") {
                            ForEach(viewModel.allTags, id: \.tag) { tagInfo in
                                HStack(spacing: 6) {
                                    Image(systemName: viewModel.selectedTags.contains(tagInfo.tag) ? "tag.fill" : "tag")
                                        .foregroundColor(viewModel.selectedTags.contains(tagInfo.tag) ? .accentColor : .secondary)
                                        .frame(width: 16)
                                    Text(tagInfo.tag.capitalized)
                                        .font(.body)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(tagInfo.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.toggleTagFilter(tagInfo.tag)
                                }
                            }
                            if !viewModel.selectedTags.isEmpty {
                                Button(action: { viewModel.clearTagFilters() }) {
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                        Text("Clear filters")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button(action: { viewModel.showTagCloud = true }) {
                                HStack {
                                    Image(systemName: "circle.grid.2x2")
                                        .foregroundColor(.secondary)
                                    Text("Show Tag Cloud")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.sm)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    @ViewBuilder
    private func sidebarSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(DesignTokens.Typography.labelStyle())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.top, DesignTokens.Spacing.xs)
                .padding(.bottom, 2)
            
            VStack(spacing: 1) {
                content()
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 2)
            .background(DesignTokens.Colors.sidebarCardBackground)
            .cornerRadius(DesignTokens.Corner.md)
        }
    }

    private var appBranding: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Corner.md)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.95, green: 0.35, blue: 0.15), Color(red: 1.00, green: 0.60, blue: 0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .shadow(color: Color(red: 0.95, green: 0.35, blue: 0.15).opacity(0.3), radius: 4, x: 0, y: 2)
                
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text("PandyDoc")
                .font(.headline.weight(.bold))
                .tracking(-0.3)
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private func sidebarItem(
        icon: String,
        label: String,
        tag: SidebarItem,
        badge: String? = nil,
        badgeColor: Color = .accentColor,
        isSelected: Bool = false,
        onDrop: (([NSItemProvider]) -> Void)? = nil
    ) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(isSelected ? .white : .accentColor)
                .frame(width: 20)
            Text(label)
                .font(.body)
                .fontWeight(isSelected ? .medium : .regular)
                .foregroundColor(isSelected ? .white : .primary)
            Spacer()
            if let badge {
                Text(badge)
                    .font(.caption.weight(.bold))
                    .foregroundColor(isSelected ? .white : badgeColor)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? Color.white.opacity(0.2) : badgeColor.opacity(0.15))
                    )
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(
            isSelected ? Color.accentColor : Color.clear
        )
        .cornerRadius(DesignTokens.Corner.sm)
        .contentShape(Rectangle())
        .onTapGesture {
            sidebarSelection = tag
        }
        .onDrop(of: [.fileURL, .plainText], isTargeted: nil) { providers in
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

    @FocusState private var folderFieldFocused: Bool

    private func startCreateFolder(parentID: UUID?) {
        viewModel.newFolderParentID = parentID
        viewModel.newFolderName = ""
        isCreatingFolder = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            folderFieldFocused = true
        }
    }

    private var statsBar: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            statItem(icon: "doc.text.fill", value: "\(viewModel.documents.count)", label: "Documents")
            statItem(icon: "folder.fill", value: "\(viewModel.folders.count)", label: "Folders")
            
            Divider()
                .frame(height: 20)
            
            if viewModel.checkedOutCount > 0 {
                statItem(icon: "pencil.circle.fill", value: "\(viewModel.checkedOutCount)", label: "Checked Out", color: .blue)
            }
            if viewModel.flaggedDocumentCount > 0 {
                statItem(icon: "flag.fill", value: "\(viewModel.flaggedDocumentCount)", label: "Flagged", color: .red)
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.statsBarBackground)
    }
    
    private func statItem(icon: String, value: String, label: String, color: Color = .secondary) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(DesignTokens.Typography.statsNumberStyle())
                .foregroundColor(.primary)
            Text(label)
                .font(DesignTokens.Typography.statsLabelStyle())
                .foregroundColor(.secondary)
        }
    }

    private var documentList: some View {
        List(viewModel.documents) { document in
            DocumentRowView(document: document, viewModel: viewModel)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedDocument = document
                }
                .background(
                    viewModel.selectedDocument?.id == document.id
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                )
                .contextMenu {
                    documentContextMenu(for: document)
                }
        }
        .listStyle(.inset)
        .searchable(text: $viewModel.searchQuery, prompt: "Search documents")
        .onChange(of: viewModel.searchQuery) { _, _ in
            viewModel.searchDocuments()
        }
        .onDrop(of: [.fileURL, .plainText], isTargeted: nil) { providers in
            handleDropToFolder(providers: providers, targetFolderID: viewModel.currentFolder?.id)
            return true
        }
        .overlay {
            if viewModel.documents.isEmpty && !viewModel.isLoading {
                emptyStateView
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: emptyIcon)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(viewModel.searchQuery.isEmpty ? emptyTitle : "No Results")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(viewModel.searchQuery.isEmpty ? emptyDescription : "No documents match \"\(viewModel.searchQuery)\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if viewModel.searchQuery.isEmpty && viewModel.isShowingAllDocuments {
                Button(action: { showImportSheet = true }) {
                    Label("Import Documents", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(DesignTokens.Spacing.xxl)
    }

    private var emptyIcon: String {
        if viewModel.isShowingTemplates { return "doc.on.doc" }
        if viewModel.isShowingAllDocuments { return "tray.and.arrow.down" }
        return "folder.badge.plus"
    }

    private var emptyTitle: String {
        if viewModel.isShowingTemplates { return "No Templates" }
        if viewModel.isShowingAllDocuments { return "No Documents" }
        return "Empty Folder"
    }

    private var emptyDescription: String {
        if viewModel.isShowingTemplates { return "Drag documents here or use \"Add to Templates\" to add templates" }
        if viewModel.isShowingAllDocuments { return "Import documents to get started" }
        return "This folder is empty"
    }

    private var detailView: some View {
        Group {
            if viewModel.selectedDocument != nil {
                DocumentQuickView(viewModel: viewModel)
                    .id("\(viewModel.selectedDocument!.id.uuidString)-\(viewModel.documentRefreshToken)")
            } else {
                VStack(spacing: 16) {
                    Image(pdfNamed: "PandaHead")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .foregroundColor(.accentColor.opacity(0.6))
                    Text("PandyDoc")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text("Select a document to preview")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func handleMixedDrop(providers: [NSItemProvider], folder: Folder) {
        handleDropToFolder(providers: providers, targetFolderID: folder.id)
    }

    private func handleDropToFolder(providers: [NSItemProvider], targetFolderID: UUID?) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.utf8-plain-text") {
                provider.loadItem(forTypeIdentifier: "public.utf8-plain-text", options: nil) { data, _ in
                    if let data = data as? Data,
                       let uuidString = String(data: data, encoding: .utf8),
                       let docID = UUID(uuidString: uuidString) {
                        DispatchQueue.main.async {
                            self.viewModel.moveDocument(documentID: docID, to: targetFolderID)
                        }
                        return
                    }
                    self.handleFileImport(provider: provider, targetFolderID: targetFolderID)
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                handleFileImport(provider: provider, targetFolderID: targetFolderID)
            } else {
                _ = provider.loadFileRepresentation(forTypeIdentifier: "public.data") { url, error in
                    guard let url = url else { return }
                    let started = url.startAccessingSecurityScopedResource()
                    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PandyDoc/Drop", isDirectory: true)
                    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                    let copyURL = tempDir.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.copyItem(at: url, to: copyURL)
                    if started {
                        url.stopAccessingSecurityScopedResource()
                    }
                    DispatchQueue.main.async {
                        self.viewModel.importDocument(fileURL: copyURL, to: targetFolderID)
                    }
                }
            }
        }
    }

    private func handleFileImport(provider: NSItemProvider, targetFolderID: UUID?) {
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            guard let urlData = item as? Data,
                  let url = URL(dataRepresentation: urlData, relativeTo: nil) else { return }
            let started = url.startAccessingSecurityScopedResource()
            DispatchQueue.main.async {
                self.viewModel.importDocument(fileURL: url, to: targetFolderID)
                if started {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
    }

    @ViewBuilder
    private func documentContextMenu(for document: Document) -> some View {
        if document.isAvailable {
            Button(action: { viewModel.checkOut(document: document) }) {
                Label("Check Out", systemImage: "square.and.arrow.down")
            }
            Button(action: { viewModel.lockDocument(document: document) }) {
                Label("Lock", systemImage: "lock")
            }
        }

        if document.isCheckedOut && document.checkedOutBy == NSFullUserName() {
            Button(action: { viewModel.saveWorkingCopy(document: document) }) {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            Button(action: { viewModel.quickCheckIn(document: document) }) {
                Label("Check In", systemImage: "square.and.arrow.up")
            }
            Button(action: { viewModel.checkInWithNotes(document: document) }) {
                Label("Check In with Notes...", systemImage: "text.badge.checkmark")
            }
            Button(action: { viewModel.discardCheckOut(document: document) }) {
                Label("Discard Changes", systemImage: "xmark.circle")
            }
        }

        if document.isLocked && document.checkedOutBy == NSFullUserName() {
            Button(action: { viewModel.unlockDocument(document: document) }) {
                Label("Unlock", systemImage: "lock.open")
            }
        }

        Divider()

        Button(action: { viewModel.toggleFlag(document) }) {
            Label(document.flagged ? "Unflag" : "Flag", systemImage: document.flagged ? "flag.fill" : "flag")
        }

        Button(action: { viewModel.startRename(document) }) {
            Label("Rename", systemImage: "pencil")
        }

        Button(action: { viewModel.toggleDocumentProtection(document) }) {
            Label(document.protected ? "Unprotect" : "Protect", systemImage: document.protected ? "lock.open" : "lock")
        }

        Button(action: { viewModel.openDocument(document: document) }) {
            Label(document.isLocked ? "Open (Locked)" : "Open", systemImage: "arrow.up.right.square")
        }
        .disabled(document.isLocked)

        Button(action: { viewModel.showVersions(for: document) }) {
            Label("Version History", systemImage: "clock.arrow.circlepath")
        }

        Divider()

        Button(action: { viewModel.exportDocument(document) }) {
            Label(document.isLocked && viewModel.isShowingTemplates ? "Export (Locked)" : "Export...", systemImage: "square.and.arrow.up")
        }
        .disabled(document.isLocked && viewModel.isShowingTemplates)

        Button(action: { viewModel.createFromTemplate(document) }) {
            Label("New from Template", systemImage: "doc.badge.plus")
        }

        if viewModel.isShowingTemplates {
            Button(action: { viewModel.removeFromTemplates(document) }) {
                Label("Remove from Templates", systemImage: "doc.on.doc")
            }
        } else {
            Button(action: { viewModel.addToTemplates(document) }) {
                Label("Add to Templates", systemImage: "doc.on.doc")
            }
        }

        Button(action: { viewModel.openDocument(document: document) }) {
            Label(document.isLocked ? "Open (Locked)" : "Open", systemImage: "arrow.up.right.square")
        }
        .disabled(document.isLocked)

        Divider()

        if viewModel.currentFolder != nil {
            Button(action: { viewModel.moveDocument(documentID: document.id, to: nil) }) {
                Label("Move to Root", systemImage: "arrow.up.to.line")
            }
        }

        if !viewModel.allFolders.isEmpty {
            Menu("Move to Folder") {
                ForEach(viewModel.folderTree) { node in
                    FolderMenuItem(node: node, action: { folderID in
                        viewModel.moveDocument(documentID: document.id, to: folderID)
                    })
                }
            }
        }

        Divider()

        Button(role: .destructive, action: { viewModel.deleteDocument(document: document) }) {
            Label(document.isLocked && viewModel.isShowingTemplates ? "Delete (Locked)" : "Delete", systemImage: "trash")
        }
        .disabled(document.isLocked && viewModel.isShowingTemplates)
    }
}

struct FolderTreeView: View {
    let nodes: [DocumentListViewModel.FolderNode]
    @Binding var selection: SidebarItem?
    @Binding var expandedFolders: Set<UUID>
    let onDropFile: (Folder, [NSItemProvider]) -> Void
    let onDeleteFolder: (Folder) -> Void
    let onRenameFolder: (Folder) -> Void
    let onArchiveFolder: (Folder) -> Void
    let onNewSubfolder: (Folder) -> Void
    let onToggleProtection: (Folder) -> Void
    let onMoveFolder: (Folder) -> Void

    @Binding var isCreatingFolder: Bool
    @Binding var newFolderName: String
    @Binding var newFolderParentID: UUID?
    @FocusState.Binding var folderFieldFocused: Bool
    let onCreateFolder: (String, UUID?) -> Void
    let onCancelCreate: () -> Void

    @Binding var showFolderRenameAlert: Bool
    @Binding var folderRenameText: String
    @Binding var folderToRename: Folder?
    @Binding var showDeleteFolderConfirmation: Bool
    @Binding var folderToDelete: Folder?
    let onPerformFolderRename: () -> Void
    let onConfirmDeleteFolder: () -> Void

    private var flatRows: [(node: DocumentListViewModel.FolderNode, depth: Int)] {
        var result: [(DocumentListViewModel.FolderNode, Int)] = []
        func flatten(_ nodes: [DocumentListViewModel.FolderNode], depth: Int) {
            for node in nodes {
                result.append((node, depth))
                if expandedFolders.contains(node.id), let children = node.children {
                    flatten(children, depth: depth + 1)
                }
            }
        }
        flatten(nodes, depth: 0)
        return result
    }

    var body: some View {
        Group {
            ForEach(flatRows, id: \.node.id) { row in
                FolderRow(
                    node: row.node,
                    depth: row.depth,
                    isExpanded: expandedFolders.contains(row.node.id),
                    selection: $selection,
                    onToggleExpand: { toggleExpand(row.node.id, hasChildren: row.node.children != nil && !row.node.children!.isEmpty) },
                    onDropFile: onDropFile,
                    onDeleteFolder: onDeleteFolder,
                    onRenameFolder: onRenameFolder,
                    onArchiveFolder: onArchiveFolder,
                    onNewSubfolder: onNewSubfolder,
                    onToggleProtection: onToggleProtection,
                    onMoveFolder: onMoveFolder,
                    showFolderRenameAlert: $showFolderRenameAlert,
                    folderRenameText: $folderRenameText,
                    folderToRename: $folderToRename,
                    showDeleteFolderConfirmation: $showDeleteFolderConfirmation,
                    folderToDelete: $folderToDelete,
                    onPerformFolderRename: onPerformFolderRename,
                    onConfirmDeleteFolder: onConfirmDeleteFolder
                )

                if isCreatingFolder, let targetID = newFolderParentID, targetID == row.node.id {
                    FolderCreateRow(
                        depth: row.depth + 1,
                        newFolderName: $newFolderName,
                        folderFieldFocused: _folderFieldFocused,
                        onCreate: { name in
                            onCreateFolder(name, targetID)
                        },
                        onCancel: onCancelCreate
                    )
                }
            }

            if isCreatingFolder && newFolderParentID == nil {
                FolderCreateRow(
                    depth: 0,
                    newFolderName: $newFolderName,
                    folderFieldFocused: _folderFieldFocused,
                    onCreate: { name in
                        onCreateFolder(name, nil)
                    },
                    onCancel: onCancelCreate
                )
            }
        }
        .onChange(of: selection) { _, newSelection in
            if case .folder(let folder) = newSelection {
                expandPath(to: folder.id)
            }
        }
    }

    private func toggleExpand(_ id: UUID, hasChildren: Bool) {
        guard hasChildren else { return }
        if expandedFolders.contains(id) {
            expandedFolders.remove(id)
        } else {
            expandedFolders.insert(id)
        }
    }

    private func expandPath(to folderID: UUID) {
        func findParentPath(in nodes: [DocumentListViewModel.FolderNode], target: UUID) -> [UUID]? {
            for node in nodes {
                if node.id == target {
                    return []
                }
                if let childPath = findParentPath(in: node.children ?? [], target: target) {
                    return [node.id] + childPath
                }
            }
            return nil
        }
        if let path = findParentPath(in: nodes, target: folderID) {
            expandedFolders.formUnion(path)
        }
    }
}

struct FolderCreateRow: View {
    let depth: Int
    @Binding var newFolderName: String
    @FocusState.Binding var folderFieldFocused: Bool
    let onCreate: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Color.clear.frame(width: 12)
            Image(systemName: "folder.badge.plus")
                .foregroundColor(.accentColor)
                .frame(width: 18)
            TextField("Folder name", text: $newFolderName)
                .textFieldStyle(.plain)
                .focused($folderFieldFocused)
                .onSubmit {
                    if !newFolderName.isEmpty {
                        onCreate(newFolderName)
                    }
                }
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, CGFloat(depth) * 16)
        .padding(.vertical, 2)
    }
}

struct FolderRow: View {
    let node: DocumentListViewModel.FolderNode
    let depth: Int
    let isExpanded: Bool
    @Binding var selection: SidebarItem?
    let onToggleExpand: () -> Void
    let onDropFile: (Folder, [NSItemProvider]) -> Void
    let onDeleteFolder: (Folder) -> Void
    let onRenameFolder: (Folder) -> Void
    let onArchiveFolder: (Folder) -> Void
    let onNewSubfolder: (Folder) -> Void
    let onToggleProtection: (Folder) -> Void
    let onMoveFolder: (Folder) -> Void

    @Binding var showFolderRenameAlert: Bool
    @Binding var folderRenameText: String
    @Binding var folderToRename: Folder?
    @Binding var showDeleteFolderConfirmation: Bool
    @Binding var folderToDelete: Folder?
    let onPerformFolderRename: () -> Void
    let onConfirmDeleteFolder: () -> Void

    private var hasChildren: Bool {
        node.children != nil && !node.children!.isEmpty
    }

    var body: some View {
        HStack(spacing: 6) {
            let isSelected = selection == .folder(node.folder)
            
            if hasChildren {
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 12)
            }

            Image(systemName: node.folder.protected ? "lock.fill" : "folder.fill")
                .foregroundColor(isSelected ? .accentColor : (node.folder.protected ? .orange : .accentColor))
                .frame(width: 18)

            Text(node.name)
                .font(.body)
                .fontWeight(isSelected ? .medium : .regular)
                .lineLimit(1)

            Spacer()
        }
        .padding(.leading, CGFloat(depth) * 16)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            selection == .folder(node.folder)
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
        .cornerRadius(DesignTokens.Corner.sm)
        .contentShape(Rectangle())
        .onTapGesture {
            selection = .folder(node.folder)
        }
        .onDrop(of: [.fileURL, .plainText], isTargeted: nil) { providers in
            onDropFile(node.folder, providers)
            return true
        }
        .contextMenu {
            Button(action: { onNewSubfolder(node.folder) }) {
                Label("New Subfolder", systemImage: "folder.badge.plus")
            }
            Button(action: { onRenameFolder(node.folder) }) {
                Label("Rename", systemImage: "pencil")
            }
            Divider()
            Button(action: { onToggleProtection(node.folder) }) {
                Label(node.folder.protected ? "Unprotect" : "Protect", systemImage: node.folder.protected ? "lock.open" : "lock")
            }
            Button(action: { onArchiveFolder(node.folder) }) {
                Label("Archive...", systemImage: "archivebox")
            }
            Button(action: { onMoveFolder(node.folder) }) {
                Label("Move to Folder...", systemImage: "folder")
            }
            Divider()
            Button(role: .destructive) {
                onDeleteFolder(node.folder)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .tag(SidebarItem.folder(node.folder))
        .alert("Rename Folder", isPresented: Binding(
            get: { showFolderRenameAlert && folderToRename?.id == node.folder.id },
            set: { if !$0 { showFolderRenameAlert = false; folderToRename = nil } }
        )) {
            TextField("Name", text: $folderRenameText)
            Button("Cancel", role: .cancel) {
                showFolderRenameAlert = false
                folderToRename = nil
            }
            Button("Rename") {
                onPerformFolderRename()
            }
        }
        .alert("Delete Folder", isPresented: Binding(
            get: { showDeleteFolderConfirmation && folderToDelete?.id == node.folder.id },
            set: { if !$0 { showDeleteFolderConfirmation = false; folderToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                showDeleteFolderConfirmation = false
                folderToDelete = nil
            }
            Button("Delete", role: .destructive) {
                onConfirmDeleteFolder()
            }
        } message: {
            Text("Delete \"\(node.folder.name)\"? Documents will be moved to All Documents.")
        }
    }
}

struct ArchiveSheetView: View {
    @ObservedObject var viewModel: DocumentListViewModel
    @State private var selectedDirectory: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let folder = viewModel.archiveFolder {
                    Text("Archive \"\(folder.name)\"")
                        .font(.headline)
                }

                if let progress = viewModel.archiveProgress {
                    ProgressView(progress)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)

                        Text("Choose a location to save the archive")
                            .foregroundColor(.secondary)

                        if let dir = selectedDirectory {
                            HStack {
                                Image(systemName: "folder.fill")
                                Text(dir.path)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                        }

                        Button("Choose Location...") {
                            let panel = NSOpenPanel()
                            panel.title = "Select Archive Location"
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.canCreateDirectories = true
                            panel.allowsMultipleSelection = false

                            if panel.runModal() == .OK, let url = panel.url {
                                selectedDirectory = url
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .frame(width: 400, height: 280)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        viewModel.showArchiveSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Archive") {
                        guard let dest = selectedDirectory else { return }
                        viewModel.performArchive(to: dest)
                    }
                    .disabled(selectedDirectory == nil || viewModel.archiveProgress != nil)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

struct FolderMoveSheetView: View {
    @ObservedObject var viewModel: DocumentListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedParent: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section("Move Folder") {
                    if let folder = viewModel.folderToMove {
                        Text("Move \"\(folder.name)\" to:")
                            .font(.body)
                    }
                }

                Section("Destination") {
                    Button(action: { selectedParent = nil }) {
                        HStack {
                            Image(systemName: "house.fill")
                                .foregroundColor(selectedParent == nil ? .accentColor : .secondary)
                            Text("All Documents (Root)")
                                .fontWeight(selectedParent == nil ? .medium : .regular)
                                .foregroundColor(selectedParent == nil ? .accentColor : .primary)
                            Spacer()
                            if selectedParent == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Divider()

                    ForEach(viewModel.folderTree) { node in
                        FolderMoveTargetRow(
                            node: node,
                            selectedParent: $selectedParent,
                            folderToMove: viewModel.folderToMove
                        )
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Move Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        viewModel.showFolderMoveSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        viewModel.performFolderMove(to: selectedParent)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 320, height: 360)
    }
}

struct FolderMoveTargetRow: View {
    let node: DocumentListViewModel.FolderNode
    @Binding var selectedParent: UUID?
    let folderToMove: Folder?
    @State private var depth: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                if node.folder.id != folderToMove?.id {
                    selectedParent = node.folder.id
                }
            }) {
                HStack {
                    Image(systemName: node.folder.protected ? "lock.fill" : "folder.fill")
                        .foregroundColor(node.folder.id == folderToMove?.id ? .gray : (selectedParent == node.folder.id ? .accentColor : .secondary))
                    Text(node.name)
                        .fontWeight(selectedParent == node.folder.id ? .medium : .regular)
                        .foregroundColor(node.folder.id == folderToMove?.id ? .gray : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    if selectedParent == node.folder.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                    if node.folder.id == folderToMove?.id {
                        Text("(current)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(node.folder.id == folderToMove?.id)
            .padding(.leading, CGFloat(depth) * 16)

            if let children = node.children {
                ForEach(children) { child in
                    FolderMoveTargetRow(
                        node: child,
                        selectedParent: $selectedParent,
                        folderToMove: folderToMove,
                        depth: depth + 1
                    )
                }
            }
        }
    }

    init(node: DocumentListViewModel.FolderNode, selectedParent: Binding<UUID?>, folderToMove: Folder?, depth: Int = 0) {
        self.node = node
        self._selectedParent = selectedParent
        self.folderToMove = folderToMove
        self._depth = State(initialValue: depth)
    }
}

struct TagCloudView: View {
    @ObservedObject var viewModel: DocumentListViewModel
    @Environment(\.dismiss) private var dismiss

    private var maxCount: Int {
        viewModel.allTags.map { $0.count }.max() ?? 1
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                FlowLayout(spacing: 8) {
                    ForEach(viewModel.allTags, id: \.tag) { tagInfo in
                        let normalizedSize = CGFloat(tagInfo.count) / CGFloat(maxCount)
                        let fontSize: CGFloat = 12 + normalizedSize * 20
                        Button(action: {
                            viewModel.toggleTagFilter(tagInfo.tag)
                        }) {
                            HStack(spacing: 4) {
                                Text(tagInfo.tag.capitalized)
                                    .font(.system(size: fontSize, weight: normalizedSize > 0.5 ? .semibold : .regular))
                                    .foregroundColor(viewModel.selectedTags.contains(tagInfo.tag) ? .white : .primary)
                                Text("\(tagInfo.count)")
                                    .font(.system(size: fontSize * 0.7))
                                    .foregroundColor(viewModel.selectedTags.contains(tagInfo.tag) ? .white.opacity(0.8) : .secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                viewModel.selectedTags.contains(tagInfo.tag)
                                    ? AnyShapeStyle(Color.accentColor)
                                    : AnyShapeStyle(Color.secondary.opacity(0.1))
                            )
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Tag Cloud")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !viewModel.selectedTags.isEmpty {
                        Button("Clear Filters") {
                            viewModel.clearTagFilters()
                        }
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}

extension Image {
    init(pdfNamed name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "pdf"),
              let image = NSImage(contentsOf: url) else {
            self.init(systemName: "pawprint.fill")
            return
        }
        self.init(nsImage: image)
    }
}
