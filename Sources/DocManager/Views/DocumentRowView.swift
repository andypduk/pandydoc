import SwiftUI
import UniformTypeIdentifiers

struct DocumentRowView: View {
    let document: Document
    @ObservedObject var viewModel: DocumentListViewModel
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            documentIcon
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(document.name)
                    .font(DesignTokens.Typography.bodyStyle())
                    .lineLimit(1)
                
                HStack(spacing: DesignTokens.Spacing.xs) {
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
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.sm)
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
    
    private var documentIcon: some View {
        let colors = DesignTokens.FileTypeColor.gradient(for: document.documentType)
        let iconName = DesignTokens.FileTypeColor.icon(for: document.documentType)
        
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
