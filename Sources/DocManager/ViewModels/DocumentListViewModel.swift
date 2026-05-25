import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class DocumentListViewModel: ObservableObject {
    @Published var documents: [Document] = []
    @Published var selectedDocument: Document?
    @Published var documentRefreshToken: Int = 0
    @Published var searchQuery = ""
    @Published var selectedTags: [String] = []
    @Published var allTags: [(tag: String, count: Int)] = []
    @Published var showTagCloud = false
    @Published var filterStatus: DocumentStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showImportSheet = false
    @Published var showVersionHistory = false
    @Published var versions: [DocumentVersion] = []
    @Published var showCheckInSheet = false
    @Published var checkInNotes = ""
    @Published var folders: [Folder] = []
    @Published var currentFolder: Folder?
    @Published var folderPath: [Folder] = []
    @Published var showNewFolderAlert = false
    @Published var newFolderName = ""
    @Published var showCheckInNotesField = false
    @Published var inlineCheckInNotes = ""
    @Published var isShowingAllDocuments = true
    @Published var isShowingTemplates = false
    @Published var showRenameAlert = false
    @Published var renameText = ""
    private var documentToRename: Document?
    @Published var showFolderRenameAlert = false
    @Published var folderRenameText = ""
    var folderToRename: Folder?
    @Published var folderNameLookup: [UUID: String] = [:]
    @Published var allFolders: [Folder] = []
    @Published var canNavigateBack = false
    @Published var canNavigateForward = false
    @Published var showDeleteFolderConfirmation = false
    @Published var folderToDelete: Folder?
    @Published var showArchiveSheet = false
    @Published var archiveFolder: Folder?
    @Published var archiveProgress: String?
    @Published var importProgress: Double?
    @Published var importCurrentFile: Int = 0
    @Published var importTotalFiles: Int = 0
    @Published var newFolderParentID: UUID?
    @Published var pendingImportURL: URL?
    @Published var pendingImportIsFolder = false
    @Published var showFolderMoveSheet = false
    @Published var folderToMove: Folder?
    @Published var folderMoveTargetParentID: UUID?

    private var templatesFolderID: UUID?
    private let templatesFolderName = "Templates"
    private var inboxFolderID: UUID?
    private let inboxFolderName = "Inbox"
    @Published var isShowingInbox = false
    var inboxDocumentCount: Int {
        guard let inboxID = inboxFolderID else { return 0 }
        return (try? storage.getDocumentsInFolder(folderID: inboxID).count) ?? 0
    }
    @Published var isShowingFlagged = false
    var flaggedDocumentCount: Int {
        storage.getAllDocumentsRecursive().filter { $0.flagged }.count
    }

    func navigateToFlagged() {
        folderPath.removeAll()
        currentFolder = nil
        isShowingTemplates = false
        isShowingInbox = false
        isShowingFlagged = true
        documents = storage.getAllDocumentsRecursive().filter { $0.flagged }
        isShowingAllDocuments = false
        recordNavigation(.flagged)
    }

    func toggleFlag(_ document: Document) {
        do {
            var updated = document
            updated.flagged.toggle()
            try storage.updateDocument(updated)
            refreshDocuments()
            if let fresh = storage.getDocument(id: document.id) {
                selectedDocument = fresh
                documentRefreshToken += 1
            }
        } catch {
            errorMessage = "Failed to toggle flag: \(error.localizedDescription)"
        }
    }

    func getTemplatesFolderID() -> UUID? {
        ensureTemplatesFolderExists()
        return templatesFolderID
    }

    func getInboxFolderID() -> UUID? {
        ensureInboxFolderExists()
        return inboxFolderID
    }

    func navigateToInbox() {
        ensureInboxFolderExists()
        folderPath.removeAll()
        currentFolder = nil
        isShowingTemplates = false
        isShowingInbox = true
        recordNavigation(.inbox)
        refreshDocuments()
    }

    private var navigationHistory: [SidebarNavigation] = []
    private var navigationIndex = -1

    enum SidebarNavigation: Hashable {
        case flagged
        case inbox
        case allDocuments
        case templates
        case folder(Folder)
    }

    var checkedOutCount: Int {
        storage.getCheckedOutByUser(username: NSFullUserName()).count
    }

    struct FolderNode: Identifiable, Hashable {
        let id: UUID
        let name: String
        let folder: Folder
        var children: [FolderNode]?

        static func == (lhs: FolderNode, rhs: FolderNode) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    var folderTree: [FolderNode] {
        let filtered = allFolders.filter { $0.id != templatesFolderID }
        return buildFolderTree(from: filtered)
    }

    private func buildFolderTree(from folders: [Folder]) -> [FolderNode] {
        func children(of parentID: UUID?) -> [FolderNode]? {
            let childFolders = folders
                .filter { $0.parentID == parentID }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            guard !childFolders.isEmpty else { return nil }
            return childFolders.map { folder in
                FolderNode(
                    id: folder.id,
                    name: folder.name,
                    folder: folder,
                    children: children(of: folder.id)
                )
            }
        }
        return children(of: nil) ?? []
    }
    
    private let storage: DocumentStorageProtocol
    private let checkInOut: CheckInOutProtocol
    private let editor: DocumentEditorService
    
    init(
        storage: DocumentStorageProtocol = DocumentStorage.shared,
        checkInOut: CheckInOutProtocol = CheckInOutService.shared,
        editor: DocumentEditorService = DocumentEditorService.shared
    ) {
        self.storage = storage
        self.checkInOut = checkInOut
        self.editor = editor
        
        setupNotifications()
        isLoading = true
    }
    
    func loadInitialData() {
        try? storage.initializeStorage()
        refreshDocuments()
        if navigationHistory.isEmpty {
            recordNavigation(.allDocuments)
        }
        isLoading = false
    }

    func freshDocument(for id: UUID) -> Document? {
        storage.getDocument(id: id)
    }
    
    func refreshDocuments() {
        ensureTemplatesFolderExists()
        ensureInboxFolderExists()
        
        if isShowingFlagged {
            documents = storage.getAllDocumentsRecursive().filter { $0.flagged }
            isShowingAllDocuments = false
            isShowingTemplates = false
            isShowingInbox = false
        } else if isShowingInbox, let inboxID = inboxFolderID {
            documents = (try? storage.getDocumentsInFolder(folderID: inboxID)) ?? []
            isShowingAllDocuments = false
            isShowingTemplates = false
        } else if isShowingTemplates, let templatesID = templatesFolderID {
            documents = (try? storage.getDocumentsInFolder(folderID: templatesID)) ?? []
        } else if let folder = currentFolder {
            documents = (try? storage.getDocumentsInFolder(folderID: folder.id)) ?? []
            isShowingAllDocuments = false
            isShowingTemplates = false
            isShowingInbox = false
        } else {
            documents = storage.getAllDocumentsRecursive()
            if let templatesID = templatesFolderID {
                documents = documents.filter { $0.parentID != templatesID }
            }
            if let inboxID = inboxFolderID {
                documents = documents.filter { $0.parentID != inboxID }
            }
            isShowingAllDocuments = true
            isShowingTemplates = false
            isShowingInbox = false
            buildFolderLookup()
        }
        folders = (try? storage.getFolders(parentID: currentFolder?.id)) ?? []
        folders = folders.filter { $0.id != templatesFolderID && $0.id != inboxFolderID }
        allFolders = storage.getAllFolders().filter { $0.id != templatesFolderID && $0.id != inboxFolderID }
        allTags = storage.getAllTags()
        applyFilters()
        if let sel = selectedDocument, let updated = documents.first(where: { $0.id == sel.id }) {
            selectedDocument = updated
        } else if let sel = selectedDocument, let fresh = storage.getDocument(id: sel.id) {
            selectedDocument = fresh
            documentRefreshToken += 1
        }
    }
    
    func searchDocuments() {
        if searchQuery.isEmpty && selectedTags.isEmpty {
            refreshDocuments()
        } else {
            documents = storage.searchDocuments(query: searchQuery, tags: selectedTags)
        }
        applyStatusFilter()
    }

    func navigateToFolder(_ folder: Folder) {
        folderPath.append(folder)
        currentFolder = folder
        recordNavigation(.folder(folder))
        refreshDocuments()
    }

    func navigateUp() {
        _ = folderPath.popLast()
        currentFolder = folderPath.last
        refreshDocuments()
    }

    func navigateToRoot() {
        folderPath.removeAll()
        currentFolder = nil
        isShowingTemplates = false
        isShowingInbox = false
        isShowingFlagged = false
        recordNavigation(.allDocuments)
        refreshDocuments()
    }

    func navigateToTemplates() {
        ensureTemplatesFolderExists()
        folderPath.removeAll()
        currentFolder = nil
        isShowingTemplates = true
        refreshDocuments()
        recordNavigation(.templates)
    }

    private func ensureTemplatesFolderExists() {
        guard templatesFolderID == nil else { return }
        let rootFolders = (try? storage.getFolders(parentID: nil)) ?? []
        if let existing = rootFolders.first(where: { $0.name == templatesFolderName }) {
            templatesFolderID = existing.id
        } else if let created = try? storage.createFolder(name: templatesFolderName, parentID: nil) {
            templatesFolderID = created.id
        }
    }

    private func ensureInboxFolderExists() {
        guard inboxFolderID == nil else { return }
        let rootFolders = (try? storage.getFolders(parentID: nil)) ?? []
        if let existing = rootFolders.first(where: { $0.name == inboxFolderName }) {
            inboxFolderID = existing.id
            if !existing.protected {
                try? storage.toggleFolderProtection(id: existing.id)
            }
        } else if let created = try? storage.createFolder(name: inboxFolderName, parentID: nil) {
            inboxFolderID = created.id
            try? storage.toggleFolderProtection(id: created.id)
        }
    }

    func createFromTemplate(_ document: Document) {
        do {
            let newName = "Copy of \(document.name)"
            let fileExt = document.fileExtension
            let newFileName = "\(newName).\(fileExt)"

            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("PandyDoc/Templates", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let destURL = tempDir.appendingPathComponent(newFileName)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(atPath: document.filePath, toPath: destURL.path)

            let attributes = try FileManager.default.attributesOfItem(atPath: destURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            let newDoc = Document.createNew(
                name: newName,
                fileName: newFileName,
                filePath: destURL.path,
                fileSize: fileSize,
                parentID: document.parentID
            )

            try storage.saveDocument(newDoc)
            _ = try storage.createVersion(
                documentId: newDoc.id,
                sourcePath: destURL.path,
                changeNotes: "Created from template: \(document.name)"
            )

            refreshDocuments()
            selectedDocument = newDoc
        } catch {
            errorMessage = "Failed to create from template: \(error.localizedDescription)"
        }
    }

    func addToTemplates(_ document: Document) {
        ensureTemplatesFolderExists()
        guard let templatesID = templatesFolderID else {
            errorMessage = "Failed to find or create Templates folder"
            return
        }
        do {
            try storage.moveDocument(documentID: document.id, to: templatesID)
            refreshDocuments()
            if let fresh = storage.getDocument(id: document.id) {
                selectedDocument = fresh
                documentRefreshToken += 1
            }
        } catch {
            errorMessage = "Failed to add to templates: \(error.localizedDescription)"
        }
    }

    func removeFromTemplates(_ document: Document) {
        do {
            try storage.moveDocument(documentID: document.id, to: nil)
            refreshDocuments()
            if let fresh = storage.getDocument(id: document.id) {
                selectedDocument = fresh
                documentRefreshToken += 1
            }
        } catch {
            errorMessage = "Failed to remove from templates: \(error.localizedDescription)"
        }
    }

    func navigateBack() {
        guard navigationIndex > 0 else { return }
        navigationIndex -= 1
        updateNavigationState()
        applyHistoryEntry()
    }

    func navigateForward() {
        guard navigationIndex < navigationHistory.count - 1 else { return }
        navigationIndex += 1
        updateNavigationState()
        applyHistoryEntry()
    }

    private func recordNavigation(_ entry: SidebarNavigation) {
        if navigationIndex < navigationHistory.count - 1 {
            navigationHistory.removeSubrange((navigationIndex + 1)...)
        }
        if let last = navigationHistory.last, last == entry {
            return
        }
        navigationHistory.append(entry)
        navigationIndex = navigationHistory.count - 1
        updateNavigationState()
    }

    private func applyHistoryEntry() {
        guard navigationIndex >= 0, navigationIndex < navigationHistory.count else { return }
        switch navigationHistory[navigationIndex] {
        case .flagged:
            folderPath.removeAll()
            currentFolder = nil
            isShowingFlagged = true
            isShowingTemplates = false
            isShowingInbox = false
        case .allDocuments:
            folderPath.removeAll()
            currentFolder = nil
            isShowingTemplates = false
            isShowingInbox = false
        case .templates:
            folderPath.removeAll()
            currentFolder = nil
            ensureTemplatesFolderExists()
            isShowingTemplates = true
            isShowingInbox = false
        case .inbox:
            folderPath.removeAll()
            currentFolder = nil
            ensureInboxFolderExists()
            isShowingInbox = true
            isShowingTemplates = false
        case .folder(let folder):
            if let idx = folderPath.firstIndex(where: { $0.id == folder.id }) {
                folderPath = Array(folderPath.prefix(through: idx))
            } else {
                folderPath.append(folder)
            }
            currentFolder = folder
            isShowingTemplates = false
            isShowingInbox = false
        }
        refreshDocuments()
    }

    private func updateNavigationState() {
        canNavigateBack = navigationIndex > 0
        canNavigateForward = navigationIndex < navigationHistory.count - 1
    }

    func createFolder(name: String, parentID: UUID? = nil) {
        let actualParent = parentID ?? currentFolder?.id
        print("Creating folder: name=\(name), parentID=\(actualParent?.uuidString ?? "nil")")
        do {
            if try storage.hasFolderWithName(name: name, parentID: actualParent, excluding: nil) {
                errorMessage = "A folder named \"\(name)\" already exists at this location"
                return
            }
            let folder = try storage.createFolder(name: name, parentID: actualParent)
            print("Folder created: \(folder.id)")
            refreshDocuments()
        } catch {
            print("Folder creation failed: \(error)")
            errorMessage = "Failed to create folder: \(error.localizedDescription)"
        }
    }

    func deleteFolder(_ folder: Folder) {
        folderToDelete = folder
        showDeleteFolderConfirmation = true
    }

    func confirmDeleteFolder() {
        guard let folder = folderToDelete else { return }
        do {
            let folderId = folder.id
            let descendants = collectDescendantIDs(of: folderId)
            try storage.deleteFolder(id: folder.id)

            if currentFolder?.id == folderId || descendants.contains(where: { $0 == currentFolder?.id }) {
                navigateToRoot()
            } else if let idx = folderPath.firstIndex(where: { $0.id == folderId || descendants.contains($0.id) }) {
                folderPath = Array(folderPath.prefix(upTo: idx))
                currentFolder = folderPath.last
            }

            refreshDocuments()
            folderToDelete = nil
            showDeleteFolderConfirmation = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func collectDescendantIDs(of folderID: UUID, visited: inout Set<UUID>) -> Set<UUID> {
        var ids = Set<UUID>()
        visited.insert(folderID)
        for child in allFolders where child.parentID == folderID {
            guard !visited.contains(child.id) else { continue }
            ids.insert(child.id)
            ids.formUnion(collectDescendantIDs(of: child.id, visited: &visited))
        }
        return ids
    }

    private func collectDescendantIDs(of folderID: UUID) -> Set<UUID> {
        var visited = Set<UUID>()
        return collectDescendantIDs(of: folderID, visited: &visited)
    }

    func startRenameFolder(_ folder: Folder) {
        folderToRename = folder
        folderRenameText = folder.name
        showFolderRenameAlert = true
    }

    func performFolderRename() {
        guard let folder = folderToRename, !folderRenameText.isEmpty else {
            showFolderRenameAlert = false
            return
        }
        guard folderRenameText != folder.name else {
            showFolderRenameAlert = false
            folderToRename = nil
            return
        }
        do {
            if try storage.isFolderProtected(id: folder.id) {
                errorMessage = "Cannot rename a protected folder. Unprotect it first."
                showFolderRenameAlert = false
                folderToRename = nil
                return
            }
            if try storage.hasFolderWithName(name: folderRenameText, parentID: folder.parentID, excluding: folder.id) {
                errorMessage = "A folder named \"\(folderRenameText)\" already exists at this location"
                showFolderRenameAlert = false
                folderToRename = nil
                return
            }
            var updated = folder
            updated.name = folderRenameText
            try storage.updateFolder(updated)
            refreshDocuments()
        } catch {
            errorMessage = "Rename failed: \(error.localizedDescription)"
        }
        showFolderRenameAlert = false
        folderToRename = nil
    }

    func checkOut(document: Document) {
        do {
            let result = try editor.openDocument(documentId: document.id)
            refreshDocuments()
            if let fresh = storage.getDocument(id: document.id) {
                selectedDocument = fresh
                documentRefreshToken += 1
            }
            NSWorkspace.shared.open(result.fileURL)
        } catch {
            errorMessage = "Check out failed: \(error.localizedDescription)"
        }
    }

    func quickCheckIn(document: Document) {
        do {
            _ = try checkInOut.checkIn(documentId: document.id, changeNotes: nil)
            refreshDocuments()
            if let fresh = storage.getDocument(id: document.id) {
                selectedDocument = fresh
                documentRefreshToken += 1
            }
        } catch {
            errorMessage = "Check in failed: \(error.localizedDescription)"
        }
    }

    func checkInWithNotes(document: Document) {
        selectedDocument = document
        showCheckInNotesField = true
        inlineCheckInNotes = ""
        showCheckInSheet = true
    }

    func performCheckIn(document: Document) {
        do {
            _ = try checkInOut.checkIn(documentId: document.id, changeNotes: checkInNotes.isEmpty ? nil : checkInNotes)
            refreshDocuments()
            if let fresh = storage.getDocument(id: document.id) {
                selectedDocument = fresh
                documentRefreshToken += 1
            }
            showCheckInSheet = false
            checkInNotes = ""
        } catch {
            errorMessage = "Check in failed: \(error.localizedDescription)"
        }
    }

    func saveWorkingCopy(document: Document) {
        do {
            _ = try checkInOut.saveWorkingCopy(documentId: document.id)
            refreshDocuments()
            if let fresh = storage.getDocument(id: document.id) {
                selectedDocument = fresh
                documentRefreshToken += 1
            }
        } catch {
            errorMessage = "Save working copy failed: \(error.localizedDescription)"
        }
    }

    func discardCheckOut(document: Document) {
        do {
            try checkInOut.discardCheckOut(documentId: document.id)
            refreshDocuments()
            if selectedDocument?.id == document.id {
                selectedDocument = nil
            }
        } catch {
            errorMessage = "Discard failed: \(error.localizedDescription)"
        }
    }

    func lockDocument(document: Document) {
        do {
            try checkInOut.lock(documentId: document.id)
            refreshDocuments()
            if let fresh = storage.getDocument(id: document.id) {
                selectedDocument = fresh
                documentRefreshToken += 1
            }
        } catch {
            errorMessage = "Lock failed: \(error.localizedDescription)"
        }
    }

    func unlockDocument(document: Document) {
        do {
            try checkInOut.unlock(documentId: document.id)
            refreshDocuments()
            if let fresh = storage.getDocument(id: document.id) {
                selectedDocument = fresh
                documentRefreshToken += 1
            }
        } catch {
            errorMessage = "Unlock failed: \(error.localizedDescription)"
        }
    }

    func canOpenDocument(_ document: Document) -> Bool {
        return !document.isLocked
    }

    func canExportTemplate(_ document: Document) -> Bool {
        return !document.isLocked || !isShowingTemplates
    }

    func canDeleteTemplate(_ document: Document) -> Bool {
        return !document.isLocked || !isShowingTemplates
    }

    func startRename(_ document: Document) {
        documentToRename = document
        renameText = document.name
        showRenameAlert = true
    }

    func performRename() {
        guard let document = documentToRename, !renameText.isEmpty else {
            showRenameAlert = false
            return
        }
        do {
            var updated = document
            updated.name = renameText
            updated.fileName = renameText + "." + document.fileExtension
            try storage.updateDocument(updated)
            refreshDocuments()
            if let fresh = storage.getDocument(id: document.id) {
                selectedDocument = fresh
                documentRefreshToken += 1
            }
        } catch {
            errorMessage = "Rename failed: \(error.localizedDescription)"
        }
        showRenameAlert = false
        documentToRename = nil
    }

    func openDocument(document: Document) {
        if document.isLocked {
            if isShowingTemplates {
                errorMessage = "Template is locked. Create a new document from this template instead."
            } else {
                errorMessage = "Document is locked. Unlock it to edit."
            }
            return
        }
        let url = URL(fileURLWithPath: document.filePath)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(url, configuration: config)
    }

    func exportDocument(_ document: Document) {
        if document.isLocked && isShowingTemplates {
            errorMessage = "Template is locked. Create a new document from this template instead."
            return
        }
        let savePanel = NSSavePanel()
        savePanel.title = "Export Document"
        savePanel.nameFieldStringValue = document.fileName
        savePanel.canCreateDirectories = true

        let fileURL = URL(fileURLWithPath: document.filePath)
        if let utType = UTType(filenameExtension: fileURL.pathExtension) {
            savePanel.allowedContentTypes = [utType]
        }

        savePanel.begin { response in
            guard response == .OK, let destURL = savePanel.url else { return }
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(atPath: document.filePath, toPath: destURL.path)
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to export document: \(error.localizedDescription)"
                }
            }
        }
    }

    func deleteDocument(document: Document) {
        if document.isLocked && isShowingTemplates {
            errorMessage = "Template is locked. Unlock it to delete."
            return
        }
        do {
            try storage.deleteDocument(id: document.id)
            refreshDocuments()
            if selectedDocument?.id == document.id {
                selectedDocument = nil
            }
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    func toggleDocumentProtection(_ document: Document) {
        do {
            try storage.toggleDocumentProtection(id: document.id)
            refreshDocuments()
        } catch {
            errorMessage = "Failed to toggle protection: \(error.localizedDescription)"
        }
    }

    func addTag(to document: Document, tag: String) {
        let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty, !document.tags.contains(normalized) else { return }
        do {
            var updated = document
            updated.tags.append(normalized)
            try storage.updateDocument(updated)
            refreshDocuments()
            if let fresh = storage.getDocument(id: document.id) {
                selectedDocument = fresh
                documentRefreshToken += 1
            }
        } catch {
            errorMessage = "Failed to add tag: \(error.localizedDescription)"
        }
    }

    func removeTag(from document: Document, tag: String) {
        do {
            var updated = document
            updated.tags.removeAll { $0 == tag }
            try storage.updateDocument(updated)
            refreshDocuments()
            if let fresh = storage.getDocument(id: document.id) {
                selectedDocument = fresh
                documentRefreshToken += 1
            }
        } catch {
            errorMessage = "Failed to remove tag: \(error.localizedDescription)"
        }
    }

    func toggleTagFilter(_ tag: String) {
        if let idx = selectedTags.firstIndex(of: tag) {
            selectedTags.remove(at: idx)
        } else {
            selectedTags.append(tag)
        }
        searchDocuments()
    }

    func clearTagFilters() {
        selectedTags.removeAll()
        searchDocuments()
    }

    func toggleFolderProtection(_ folder: Folder) {
        do {
            try storage.toggleFolderProtection(id: folder.id)
            refreshDocuments()
        } catch {
            errorMessage = "Failed to toggle protection: \(error.localizedDescription)"
        }
    }

    func restoreVersion(documentId: UUID, versionNumber: Int) {
        do {
            _ = try storage.restoreVersion(documentId: documentId, versionNumber: versionNumber)
            refreshDocuments()
            if let fresh = storage.getDocument(id: documentId) {
                selectedDocument = fresh
                documentRefreshToken += 1
            }
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    func moveDocument(documentID: UUID, to folderID: UUID?) {
        do {
            try storage.moveDocument(documentID: documentID, to: folderID)
            refreshDocuments()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func archiveFolder(_ folder: Folder) {
        archiveFolder = folder
        showArchiveSheet = true
    }

    func moveFolder(_ folder: Folder) {
        folderToMove = folder
        folderMoveTargetParentID = nil
        showFolderMoveSheet = true
    }

    func performFolderMove(to targetParentID: UUID?) {
        guard let folder = folderToMove else { return }
        guard folder.id != targetParentID else {
            showFolderMoveSheet = false
            return
        }
        do {
            if try storage.isFolderProtected(id: folder.id) {
                errorMessage = "Cannot move a protected folder. Unprotect it first."
                showFolderMoveSheet = false
                folderToMove = nil
                return
            }
        } catch {
            errorMessage = "Failed to move folder: \(error.localizedDescription)"
            return
        }
        func isDescendant(of parentID: UUID?, target: UUID) -> Bool {
            guard let parentID = parentID else { return false }
            if parentID == target { return true }
            let parentFolder = allFolders.first(where: { $0.id == parentID })
            return isDescendant(of: parentFolder?.parentID, target: target)
        }
        if isDescendant(of: targetParentID, target: folder.id) {
            errorMessage = "Cannot move a folder into itself or its subfolders"
            return
        }
        do {
            try storage.moveFolder(id: folder.id, to: targetParentID)
            refreshDocuments()
            showFolderMoveSheet = false
            folderToMove = nil
        } catch {
            errorMessage = "Failed to move folder: \(error.localizedDescription)"
        }
    }

    func performArchive(to destinationURL: URL) {
        guard let folder = archiveFolder else { return }
        archiveProgress = "Archiving \"\(folder.name)\"..."

        Task {
            do {
                let docs = try storage.getDocumentsInFolder(folderID: folder.id)
                guard !docs.isEmpty else {
                    archiveProgress = nil
                    errorMessage = "Folder is empty, nothing to archive."
                    return
                }

                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PandyDoc/Archive/\(folder.id.uuidString)", isDirectory: true)
                try? FileManager.default.removeItem(at: tempDir)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                for doc in docs {
                    let src = URL(fileURLWithPath: doc.filePath)
                    let dest = tempDir.appendingPathComponent(doc.fileName)
                    if FileManager.default.fileExists(atPath: src.path) {
                        try FileManager.default.copyItem(at: src, to: dest)
                    }
                }

                let zipURL = destinationURL.appendingPathComponent("\(folder.name).zip")
                try createZipArchive(from: tempDir, to: zipURL)
                try? FileManager.default.removeItem(at: tempDir)

                archiveProgress = nil
                showArchiveSheet = false
                archiveFolder = nil
            } catch {
                archiveProgress = nil
                errorMessage = "Archive failed: \(error.localizedDescription)"
            }
        }
    }

    private func createZipArchive(from sourceDir: URL, to zipURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", sourceDir.path, zipURL.path]
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(domain: "PandyDoc", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create zip archive"])
        }
    }
    
    func importDocument(fileURL: URL, to folderID: UUID? = nil) {
        Task {
            let started = fileURL.startAccessingSecurityScopedResource()
            await performFileImportAsync(fileURL: fileURL, to: folderID)
            if started {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
    }

    func importFolder(folderURL: URL) {
        Task {
            let started = folderURL.startAccessingSecurityScopedResource()
            await performFolderImportAsync(folderURL: folderURL)
            if started {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
    }

    func importDocumentWithAccessCheck(fileURL: URL, to folderID: UUID? = nil) {
        if !FolderAccessManager.shared.hasAccess(to: fileURL) {
            pendingImportURL = fileURL
            pendingImportIsFolder = false
            return
        }
        Task {
            let started = fileURL.startAccessingSecurityScopedResource()
            await performFileImportAsync(fileURL: fileURL, to: folderID)
            if started {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
    }

    func importFolderWithAccessCheck(folderURL: URL) {
        if !FolderAccessManager.shared.hasAccess(to: folderURL) {
            pendingImportURL = folderURL
            pendingImportIsFolder = true
            return
        }
        Task {
            let started = folderURL.startAccessingSecurityScopedResource()
            await performFolderImportAsync(folderURL: folderURL)
            if started {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
    }

    func grantAccessAndImport(folderURL: URL) {
        do {
            try FolderAccessManager.shared.grantAccess(to: folderURL)
            FolderAccessManager.shared.resolveAllBookmarks()

            if pendingImportIsFolder {
                Task {
                    let started = folderURL.startAccessingSecurityScopedResource()
                    await performFolderImportAsync(folderURL: folderURL)
                    if started {
                        folderURL.stopAccessingSecurityScopedResource()
                    }
                }
            } else if let url = pendingImportURL {
                Task {
                    let started = url.startAccessingSecurityScopedResource()
                    await performFileImportAsync(fileURL: url, to: nil)
                    if started {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
            pendingImportURL = nil
            pendingImportIsFolder = false
        } catch {
            errorMessage = "Failed to grant folder access: \(error.localizedDescription)"
        }
    }

    private func performFileImportAsync(fileURL: URL, to folderID: UUID?) async {
        do {
            let fileName = fileURL.lastPathComponent
            let docName = (fileName as NSString).deletingPathExtension
            
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PandyDoc/Import", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let destURL = tempDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: fileURL, to: destURL)
            
            let attributes = try FileManager.default.attributesOfItem(atPath: destURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            let document = Document.createNew(
                name: docName,
                fileName: fileName,
                filePath: destURL.path,
                fileSize: fileSize,
                parentID: folderID
            )
            
            try storage.saveDocument(document)
            _ = try storage.createVersion(
                documentId: document.id,
                sourcePath: destURL.path,
                changeNotes: "Initial import"
            )
            
            await MainActor.run {
                refreshDocuments()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to import document: \(error.localizedDescription)"
            }
        }
    }

    private func performFolderImportAsync(folderURL: URL) async {
        let fileManager = FileManager.default
        let rootName = folderURL.lastPathComponent
        var folderMap: [String: UUID] = [:]
        var importCount = 0
        var errorCount = 0

        guard let rootFolder = try? storage.createFolder(name: rootName, parentID: currentFolder?.id) else {
            await MainActor.run {
                errorMessage = "Failed to create root folder. A folder with this name may already exist."
            }
            return
        }
        folderMap[""] = rootFolder.id

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            await MainActor.run {
                errorMessage = "Failed to read folder contents"
            }
            return
        }

        let items = enumerator.allObjects.compactMap { $0 as? URL }
        let totalFiles = items.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == false
        }.count

        await MainActor.run {
            importTotalFiles = totalFiles
            importCurrentFile = 0
            importProgress = totalFiles > 0 ? 0 : nil
        }

        for fileURL in items {
            let relativePath = String(fileURL.path.dropFirst(folderURL.path.count + 1))
            let relativeDir = (relativePath as NSString).deletingLastPathComponent

            do {
                let attributes = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if attributes.isDirectory == true {
                    let folderName = fileURL.lastPathComponent
                    let parentID = folderMap[relativeDir.isEmpty ? "" : relativeDir] ?? rootFolder.id
                    let existingID = findExistingFolder(named: folderName, parentID: parentID)
                    if let existing = existingID {
                        folderMap[relativePath] = existing
                    } else if let newFolder = try? storage.createFolder(name: folderName, parentID: parentID) {
                        folderMap[relativePath] = newFolder.id
                    } else {
                        errorCount += 1
                    }
                } else {
                    let parentID = folderMap[relativeDir.isEmpty ? "" : relativeDir] ?? rootFolder.id
                    await performFileImportAsync(fileURL: fileURL, to: parentID)
                    importCount += 1

                    await MainActor.run {
                        importCurrentFile = importCount
                        importProgress = totalFiles > 0 ? Double(importCount) / Double(totalFiles) : 1.0
                    }
                }
            } catch {
                errorCount += 1
            }
        }

        await MainActor.run {
            importProgress = nil
            refreshDocuments()
            if importCount > 0 {
                if errorCount > 0 {
                    errorMessage = "Imported \(importCount) files (\(errorCount) errors)"
                }
            } else if errorCount > 0 {
                errorMessage = "Failed to import files"
            }
        }
    }

    private func findExistingFolder(named name: String, parentID: UUID) -> UUID? {
        let parentFolders = (try? storage.getFolders(parentID: parentID)) ?? []
        return parentFolders.first(where: { $0.name == name })?.id
    }

    func folderName(for document: Document) -> String? {
        guard let parentID = document.parentID else { return nil }
        return folderNameLookup[parentID]
    }

    private func buildFolderLookup() {
        var lookup: [UUID: String] = [:]
        var stack: [UUID?] = [nil]
        while let currentParent = stack.popLast() {
            if let subFolders = try? storage.getFolders(parentID: currentParent) {
                for folder in subFolders where folder.id != templatesFolderID {
                    lookup[folder.id] = folder.name
                    stack.append(folder.id)
                }
            }
        }
        folderNameLookup = lookup
    }

    func getStatusIcon(_ status: DocumentStatus) -> String {
        switch status {
        case .available: return "checkmark.circle.fill"
        case .checkedOut: return "pencil.circle.fill"
        case .locked: return "lock.fill"
        }
    }
    
    func getStatusColor(_ status: DocumentStatus) -> Color {
        switch status {
        case .available: return .green
        case .checkedOut: return .blue
        case .locked: return .red
        }
    }
    
    private func applyFilters() {
        applyStatusFilter()
    }
    
    private func applyStatusFilter() {
        guard let filter = filterStatus else { return }
        documents = documents.filter { $0.status == filter }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .documentReceived,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDocuments()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .documentCheckedIn,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDocuments()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .documentExternallyModified,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.refreshDocuments()
                if let docID = notification.userInfo?["documentId"] as? UUID,
                   let fresh = self.storage.getDocument(id: docID) {
                    self.selectedDocument = fresh
                    self.documentRefreshToken += 1
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .documentVersionCreated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let docID = notification.userInfo?["documentId"] as? UUID,
                   let fresh = self.storage.getDocument(id: docID) {
                    self.selectedDocument = fresh
                    self.documentRefreshToken += 1
                }
                self.refreshDocuments()
            }
        }
    }

    func showVersions(for document: Document) {
        selectedDocument = document
        versions = storage.getVersions(documentId: document.id)
        showVersionHistory = true
    }
}
