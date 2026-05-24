import SwiftUI
import UniformTypeIdentifiers

struct DocumentRowView: View {
    let document: Document
    @ObservedObject var viewModel: DocumentListViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            documentIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(document.name)
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.getStatusColor(document.status))
                        .frame(width: 8, height: 8)
                    
                    Text(statusText)
                        .font(.caption)
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

            if document.isCheckedOut {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            
            if document.isLocked {
                Image(systemName: "lock.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if document.protected {
                Image(systemName: "shield.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
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
    
    private var documentIcon: some View {
        Group {
            switch document.documentType {
            case .pdf:
                Image(systemName: "doc.richtext")
                    .foregroundColor(.red)
            case .docx:
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
            case .xlsx:
                Image(systemName: "tablecells")
                    .foregroundColor(.green)
            case .pptx:
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.orange)
            case .txt:
                Image(systemName: "doc.plaintext")
                    .foregroundColor(.gray)
            case .rtf:
                Image(systemName: "doc.richtext")
                    .foregroundColor(.orange)
            case .pages:
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)
            case .numbers:
                Image(systemName: "tablecells.fill")
                    .foregroundColor(.green)
            case .key:
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.orange)
            case .other:
                Image(systemName: "doc")
                    .foregroundColor(.gray)
            }
        }
        .font(.title2)
        .frame(width: 32, height: 32)
    }
    
    private var statusText: String {
        switch document.status {
        case .available: return "Available"
        case .checkedOut:
            if document.checkedOutBy == NSFullUserName() {
                return "Checked out by you"
            }
            return "Checked out by \(document.checkedOutBy ?? "unknown")"
        case .locked: return "Locked"
        }
    }
    
    @ViewBuilder
    private var documentContextMenu: some View {
        if document.isAvailable {
            Button(action: { viewModel.checkOut(document: document) }) {
                Label("Check Out", systemImage: "square.and.arrow.down")
            }
            Button(action: { viewModel.lockDocument(document: document) }) {
                Label("Lock", systemImage: "lock")
            }
        }
        
        if document.isCheckedOut && document.checkedOutBy == NSFullUserName() {
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

        Button(action: { viewModel.exportDocument(document) }) {
            Label(document.isLocked && viewModel.isShowingTemplates ? "Export (Locked)" : "Export...", systemImage: "square.and.arrow.up")
        }
        .disabled(document.isLocked && viewModel.isShowingTemplates)

        Button(action: { viewModel.openDocument(document: document) }) {
            Label(document.isLocked ? "Open (Locked)" : "Open", systemImage: "arrow.up.right.square")
        }
        .disabled(document.isLocked)
        
        Button(action: { viewModel.showVersions(for: document) }) {
            Label("Version History", systemImage: "clock.arrow.circlepath")
        }

        if !viewModel.allFolders.isEmpty {
            Divider()
            
            if viewModel.currentFolder != nil {
                Button(action: { viewModel.moveDocument(documentID: document.id, to: nil) }) {
                    Label("Move to Root", systemImage: "arrow.up.to.line")
                }
            }

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
