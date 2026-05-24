import SwiftUI

enum SidebarItem: Hashable {
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
    @State private var showHelpSheet = false
    @State private var showGettingStartedSheet = false
    @State private var showShortcutsSheet = false
    @State private var expandedFolders: Set<UUID> = []

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } content: {
            documentList
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
        .sheet(isPresented: $showHelpSheet) {
            HelpSheetView()
        }
        .sheet(isPresented: $showGettingStartedSheet) {
            GettingStartedSheetView()
        }
        .sheet(isPresented: $showShortcutsSheet) {
            KeyboardShortcutsSheetView()
        }
        .onAppear {
            viewModel.loadInitialData()
            NotificationCenter.default.addObserver(
                forName: .showPrinterSetup, object: nil, queue: .main
            ) { _ in showPrinterSetup = true }
            NotificationCenter.default.addObserver(
                forName: .showHelp, object: nil, queue: .main
            ) { _ in showHelpSheet = true }
            NotificationCenter.default.addObserver(
                forName: .showGettingStarted, object: nil, queue: .main
            ) { _ in showGettingStartedSheet = true }
            NotificationCenter.default.addObserver(
                forName: .showShortcuts, object: nil, queue: .main
            ) { _ in showShortcutsSheet = true }
            NotificationCenter.default.addObserver(
                forName: .navigateToAllDocuments, object: nil, queue: .main
            ) { [weak viewModel] _ in Task { @MainActor in viewModel?.navigateToRoot() } }
            NotificationCenter.default.addObserver(
                forName: .navigateToTemplates, object: nil, queue: .main
            ) { [weak viewModel] _ in Task { @MainActor in viewModel?.navigateToTemplates() } }
            NotificationCenter.default.addObserver(
                forName: .navigateToInbox, object: nil, queue: .main
            ) { [weak viewModel] _ in Task { @MainActor in viewModel?.navigateToInbox() } }
        }
        .onChange(of: sidebarSelection) { _, newSelection in
            switch newSelection {
            case .inbox: viewModel.navigateToInbox()
            case .allDocuments, .none: viewModel.navigateToRoot()
            case .templates: viewModel.navigateToTemplates()
            case .folder(let folder): viewModel.navigateToFolder(folder)
            }
        }
        .onChange(of: viewModel.currentFolder) { _, _ in
            if let folder = viewModel.currentFolder {
                sidebarSelection = .folder(folder)
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
        VStack(spacing: 0) {
            appBranding
            Divider()
            List(selection: $sidebarSelection) {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "tray.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 20)
                    Text("Inbox")
                        .font(.body)
                        .fontWeight(viewModel.isShowingInbox ? .medium : .regular)
                    Spacer()
                    if viewModel.inboxDocumentCount > 0 {
                        Text("\(viewModel.inboxDocumentCount)")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .tag(SidebarItem.inbox)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDropToFolder(providers: providers, targetFolderID: viewModel.getInboxFolderID())
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

                HStack(spacing: 8) {
                    Image(systemName: viewModel.isShowingAllDocuments ? "house.fill" : "house")
                        .foregroundColor(.accentColor)
                        .frame(width: 20)
                    Text("All Documents")
                        .font(.body)
                        .fontWeight(viewModel.isShowingAllDocuments ? .medium : .regular)
                    Spacer()
                    if viewModel.checkedOutCount > 0 {
                        Text("\(viewModel.checkedOutCount)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .tag(SidebarItem.allDocuments)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDropToFolder(providers: providers, targetFolderID: nil)
                    return true
                }
                .contextMenu {
                    Button(action: { showImportSheet = true }) {
                        Label("Import Document...", systemImage: "square.and.arrow.down")
                    }
                    Divider()
                    Button(action: { startCreateFolder(parentID: nil) }) {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                    Button(action: { viewModel.refreshDocuments() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }

                if viewModel.isShowingAllDocuments {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.isShowingTemplates ? "doc.on.doc.fill" : "doc.on.doc")
                            .foregroundColor(.accentColor)
                            .frame(width: 20)
                        Text("Templates")
                            .font(.body)
                            .fontWeight(viewModel.isShowingTemplates ? .medium : .regular)
                        Spacer()
                    }
                    .tag(SidebarItem.templates)
                    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                        handleDropToFolder(providers: providers, targetFolderID: viewModel.getTemplatesFolderID())
                        return true
                    }
                    .contextMenu {
                        Button(action: { viewModel.navigateToTemplates() }) {
                            Label("Show Templates", systemImage: "doc.on.doc")
                        }
                        Button(action: { startCreateFolder(parentID: viewModel.getTemplatesFolderID()) }) {
                            Label("New Template Folder", systemImage: "folder.badge.plus")
                        }
                    }
                }
            }

            Section {
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
            } header: {
                HStack {
                    Text("Folders")
                    Spacer()
                    Button(action: { startCreateFolder(parentID: nil) }) {
                        Image(systemName: "folder.badge.plus")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("New Folder")
                }
            }
        }
        .listStyle(SidebarListStyle())
        }
    }

    private var appBranding: some View {
        HStack(spacing: 8) {
            Image(systemName: "pawprint.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            Text("PandyDoc")
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
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
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDropToFolder(providers: providers, targetFolderID: viewModel.currentFolder?.id)
            return true
        }
        .overlay {
            if viewModel.documents.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    viewModel.searchQuery.isEmpty ? emptyTitle : "No Results",
                    systemImage: emptyIcon,
                    description: Text(viewModel.searchQuery.isEmpty
                        ? emptyDescription
                        : "No documents match \"\(viewModel.searchQuery)\"")
                )
            }
        }
    }

    private var emptyIcon: String {
        if viewModel.searchQuery.isEmpty && viewModel.isShowingAllDocuments {
            return "pawprint.fill"
        }
        if viewModel.isShowingTemplates { return "doc.on.doc" }
        return "doc"
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
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 64))
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
                            viewModel.moveDocument(documentID: docID, to: targetFolderID)
                        }
                        return
                    }
                }
            }
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                    guard let urlData = item as? Data,
                          let url = URL(dataRepresentation: urlData, relativeTo: nil) else { return }
                    let started = url.startAccessingSecurityScopedResource()
                    DispatchQueue.main.async {
                        viewModel.importDocument(fileURL: url, to: targetFolderID)
                        if started {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                }
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
                        viewModel.importDocument(fileURL: copyURL, to: targetFolderID)
                    }
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

        Button(action: { viewModel.startRename(document) }) {
            Label("Rename", systemImage: "pencil")
        }

        Button(action: { viewModel.toggleDocumentProtection(document) }) {
            Label(document.protected ? "Unprotect" : "Protect", systemImage: document.protected ? "lock.open" : "lock")
        }

        Button(action: { viewModel.openDocument(document: document) }) {
            Label("Open", systemImage: "arrow.up.right.square")
        }

        Button(action: { viewModel.showVersions(for: document) }) {
            Label("Version History", systemImage: "clock.arrow.circlepath")
        }

        Divider()

        Button(action: { viewModel.exportDocument(document) }) {
            Label("Export...", systemImage: "square.and.arrow.up")
        }

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
            Label("Open", systemImage: "arrow.up.right.square")
        }

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
            Label("Delete", systemImage: "trash")
        }
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
            if hasChildren {
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 12)
            }

            Image(systemName: node.folder.protected ? "lock.fill" : "folder.fill")
                .foregroundColor(node.folder.protected ? .orange : .accentColor)
                .frame(width: 18)

            Text(node.name)
                .font(.body)
                .lineLimit(1)

            Spacer()
        }
        .padding(.leading, CGFloat(depth) * 16)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            selection = .folder(node.folder)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
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

struct HelpSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    helpSection(
                        title: "Getting Started",
                        icon: "sparkles",
                        content: [
                            "Import documents by clicking the Import button or dragging files into PandyDoc",
                            "Create folders to organize your documents using the + button in the sidebar",
                            "Right-click on any folder or document for additional options",
                            "Select a document to preview it in the right panel"
                        ]
                    )

                    helpSection(
                        title: "Document Management",
                        icon: "doc.text",
                        content: [
                            "Check Out a document to edit it - a working copy opens in the default app",
                            "Save your changes and Check In to create a new version",
                            "Lock documents to prevent others from editing",
                            "View version history to see all changes and restore previous versions",
                            "Export documents to save a copy outside PandyDoc"
                        ]
                    )

                    helpSection(
                        title: "Templates",
                        icon: "doc.on.doc",
                        content: [
                            "Add any document to Templates for reuse",
                            "Create new documents from templates with a single click",
                            "Templates are stored in a special Templates folder"
                        ]
                    )

                    helpSection(
                        title: "Print to PandyDoc",
                        icon: "printer",
                        content: [
                            "Install the PDF Service from Printer Setup to add 'Save to PandyDoc' to print dialogs",
                            "From any app, press Cmd+P and select 'Save to PandyDoc' from the PDF menu",
                            "The PDF will be saved directly to your PandyDoc library"
                        ]
                    )

                    helpSection(
                        title: "Folder Organization",
                        icon: "folder",
                        content: [
                            "Create nested folder structures for better organization",
                            "Right-click folders to create subfolders, rename, move, or archive",
                            "Drag and drop documents directly onto folders to import them",
                            "Protect folders to prevent accidental deletion"
                        ]
                    )

                    helpSection(
                        title: "Supported Formats",
                        icon: "doc.text.magnifyingglass",
                        content: [
                            "PDF - Native preview with PDFKit",
                            "Pages, Numbers, Keynote - QuickLook preview",
                            "Word (DOCX), PowerPoint (PPTX), Excel (XLSX) - QuickLook preview",
                            "Text (TXT) and Rich Text (RTF) - QuickLook preview"
                        ]
                    )
                }
                .padding()
            }
            .navigationTitle("PandyDoc Help")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 520, height: 520)
    }

    private func helpSection(title: String, icon: String, content: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(content, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 4))
                            .foregroundColor(.secondary)
                            .padding(.top, 6)
                        Text(item)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

struct GettingStartedSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                        Text("Welcome to PandyDoc")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Your document management system for macOS")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    GettingStartedStep(
                        number: 1,
                        title: "Import Your Documents",
                        description: "Click Import or drag files into PandyDoc. You can also import entire folders.",
                        shortcut: "Cmd+I"
                    )

                    GettingStartedStep(
                        number: 2,
                        title: "Organize with Folders",
                        description: "Create folders and subfolders to keep your documents organized. Right-click any folder for more options.",
                        shortcut: nil
                    )

                    GettingStartedStep(
                        number: 3,
                        title: "Check Out & Edit",
                        description: "Right-click a document and select Check Out. It opens in your default app for editing.",
                        shortcut: nil
                    )

                    GettingStartedStep(
                        number: 4,
                        title: "Check In Changes",
                        description: "When done editing, check in the document to save a new version with optional notes.",
                        shortcut: "Cmd+Shift+S"
                    )

                    GettingStartedStep(
                        number: 5,
                        title: "Print from Any App",
                        description: "Install the PDF Service in Printer Setup, then select 'Save to PandyDoc' from the PDF menu in any print dialog.",
                        shortcut: nil
                    )
                }
                .padding()
            }
            .navigationTitle("Getting Started")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 480, height: 520)
    }
}

struct GettingStartedStep: View {
    let number: Int
    let title: String
    let description: String
    let shortcut: String?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text("\(number)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                    if let shortcut = shortcut {
                        Text(shortcut)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct KeyboardShortcutsSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("File Operations") {
                    ShortcutRow(action: "Import Document", shortcut: "Cmd+I")
                    ShortcutRow(action: "Import Folder", shortcut: "Cmd+Opt+I")
                    ShortcutRow(action: "Check In Document", shortcut: "Cmd+Shift+S")
                }

                Section("Navigation") {
                    ShortcutRow(action: "Show All Documents", shortcut: "Cmd+1")
                    ShortcutRow(action: "Show Templates", shortcut: "Cmd+2")
                    ShortcutRow(action: "Toggle Sidebar", shortcut: "Cmd+Opt+0")
                }

                Section("Help") {
                    ShortcutRow(action: "Open Help", shortcut: "Cmd+?")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Keyboard Shortcuts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 400, height: 340)
    }
}

struct ShortcutRow: View {
    let action: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)
                .monospacedDigit()
        }
    }
}
