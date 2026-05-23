import SwiftUI

enum SidebarItem: Hashable {
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
        .alert("Rename Folder", isPresented: $viewModel.showFolderRenameAlert) {
            TextField("Name", text: $viewModel.folderRenameText)
            Button("Cancel", role: .cancel) { viewModel.showFolderRenameAlert = false }
            Button("Rename") { viewModel.performFolderRename() }
        }
        .alert("Delete Folder", isPresented: $viewModel.showDeleteFolderConfirmation) {
            Button("Cancel", role: .cancel) { viewModel.folderToDelete = nil }
            Button("Delete", role: .destructive) { viewModel.confirmDeleteFolder() }
        } message: {
            if let folder = viewModel.folderToDelete {
                Text("Delete \"\(folder.name)\"? Documents will be moved to All Documents.")
            }
        }
        .sheet(isPresented: $viewModel.showArchiveSheet) {
            ArchiveSheetView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.loadInitialData()
            NotificationCenter.default.addObserver(
                forName: .showPrinterSetup, object: nil, queue: .main
            ) { _ in showPrinterSetup = true }
        }
        .onChange(of: sidebarSelection) { _, newSelection in
            switch newSelection {
            case .allDocuments, .none: viewModel.navigateToRoot()
            case .templates: viewModel.navigateToTemplates()
            case .folder(let folder): viewModel.navigateToFolder(folder)
            }
        }
        .onChange(of: viewModel.currentFolder) { _, _ in
            if let folder = viewModel.currentFolder {
                sidebarSelection = .folder(folder)
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
        List(selection: $sidebarSelection) {
            Section {
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
                    handleFileDrop(providers: providers, targetFolderID: nil)
                    return true
                }
                .contextMenu {
                    Button(action: { startCreateFolder(parentID: nil) }) {
                        Label("New Folder", systemImage: "folder.badge.plus")
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
                        handleFileDrop(providers: providers, targetFolderID: viewModel.getTemplatesFolderID())
                        return true
                    }
                }
            }

            Section {
                FolderTreeView(nodes: viewModel.folderTree, selection: $sidebarSelection,
                    onDropFile: { folderID, providers in
                        handleFileDrop(providers: providers, targetFolderID: folderID)
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
                    isCreatingFolder: $isCreatingFolder,
                    newFolderName: $viewModel.newFolderName,
                    newFolderParentID: $viewModel.newFolderParentID,
                    folderFieldFocused: $folderFieldFocused,
                    onCreateFolder: { name, parentID in
                        viewModel.createFolder(name: name, parentID: parentID)
                        viewModel.newFolderName = ""
                        isCreatingFolder = false
                        viewModel.newFolderParentID = nil
                    },
                    onCancelCreate: {
                        isCreatingFolder = false
                        viewModel.newFolderName = ""
                        viewModel.newFolderParentID = nil
                    }
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
            handleFileDrop(providers: providers, targetFolderID: viewModel.currentFolder?.id)
            return true
        }
        .overlay {
            if viewModel.documents.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    viewModel.searchQuery.isEmpty ? emptyTitle : "No Results",
                    systemImage: viewModel.isShowingTemplates ? "doc.on.doc" : "doc",
                    description: Text(viewModel.searchQuery.isEmpty
                        ? emptyDescription
                        : "No documents match \"\(viewModel.searchQuery)\"")
                )
            }
        }
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
            if let document = viewModel.selectedDocument {
                DocumentDetailView(document: document, viewModel: viewModel)
            } else {
                ContentUnavailableView(
                    "No Document Selected",
                    systemImage: "doc",
                    description: Text("Select a document from the list to view details")
                )
            }
        }
    }

    private func handleFileDrop(providers: [NSItemProvider], targetFolderID: UUID?) {
        for provider in providers {
            _ = provider.loadDataRepresentation(for: .fileURL) { data, error in
                guard let data = data,
                      let path = String(data: data, encoding: .utf8),
                      let url = URL(string: path) else { return }
                DispatchQueue.main.async {
                    viewModel.importDocument(fileURL: url, to: targetFolderID)
                }
            }
        }
    }

    private func handleMixedDrop(providers: [NSItemProvider], folder: Folder) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                _ = provider.loadDataRepresentation(for: .fileURL) { data, error in
                    guard let data = data,
                          let path = String(data: data, encoding: .utf8),
                          let url = URL(string: path) else { return }
                    DispatchQueue.main.async {
                        viewModel.importDocument(fileURL: url, to: folder.id)
                    }
                }
            } else {
                provider.loadItem(forTypeIdentifier: "public.utf8-plain-text", options: nil) { data, _ in
                    if let data = data as? Data,
                       let uuidString = String(data: data, encoding: .utf8),
                       let docID = UUID(uuidString: uuidString) {
                        DispatchQueue.main.async {
                            viewModel.moveDocument(documentID: docID, to: folder.id)
                        }
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
    @State private var expandedFolders: Set<UUID> = []
    let onDropFile: (UUID, [NSItemProvider]) -> Void
    let onDeleteFolder: (Folder) -> Void
    let onRenameFolder: (Folder) -> Void
    let onArchiveFolder: (Folder) -> Void
    let onNewSubfolder: (Folder) -> Void
    let onToggleProtection: (Folder) -> Void

    @Binding var isCreatingFolder: Bool
    @Binding var newFolderName: String
    @Binding var newFolderParentID: UUID?
    @FocusState.Binding var folderFieldFocused: Bool
    let onCreateFolder: (String, UUID?) -> Void
    let onCancelCreate: () -> Void

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
        VStack(spacing: 0) {
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
                    onToggleProtection: onToggleProtection
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
    let onDropFile: (UUID, [NSItemProvider]) -> Void
    let onDeleteFolder: (Folder) -> Void
    let onRenameFolder: (Folder) -> Void
    let onArchiveFolder: (Folder) -> Void
    let onNewSubfolder: (Folder) -> Void
    let onToggleProtection: (Folder) -> Void

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
            onDropFile(node.folder.id, providers)
            return true
        }
        .contextMenu {
            Button(action: { onNewSubfolder(node.folder) }) {
                Label("New Subfolder", systemImage: "folder.badge.plus")
            }
            Button(action: { onRenameFolder(node.folder) }) {
                Label("Rename", systemImage: "pencil")
            }
            Button(action: { onToggleProtection(node.folder) }) {
                Label(node.folder.protected ? "Unprotect" : "Protect", systemImage: node.folder.protected ? "lock.open" : "lock")
            }
            Button(action: { onArchiveFolder(node.folder) }) {
                Label("Archive...", systemImage: "archivebox")
            }
            Divider()
            Button(role: .destructive) {
                onDeleteFolder(node.folder)
            } label: {
                Label("Delete", systemImage: "trash")
            }
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
