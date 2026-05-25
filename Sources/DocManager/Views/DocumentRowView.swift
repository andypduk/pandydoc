import SwiftUI
import UniformTypeIdentifiers

struct DocumentRowView: View {
    let document: Document
    @ObservedObject var viewModel: DocumentListViewModel
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            fileTypeBadge
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(DesignTokens.Typography.bodyStyle())
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    statusPill
                    
                    if !document.tags.isEmpty {
                        tagDots
                    }
                    
                    if viewModel.isShowingAllDocuments,
                       let folderName = viewModel.folderName(for: document) {
                        HStack(spacing: 2) {
                            Image(systemName: "folder")
                                .font(.caption2)
                            Text(folderName)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if isHovered {
                hoverActions
                    .transition(.opacity)
            } else {
                staticIndicators
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onDrag {
            let provider = NSItemProvider()
            provider.suggestedName = document.fileName
            provider.registerFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier, fileOptions: [], visibility: .all) { completion in
                let fileURL: URL
                if let filePath = self.document.filePath {
                    fileURL = URL(fileURLWithPath: filePath)
                } else {
                    do {
                        fileURL = try self.viewModel.decompressDocumentIfNeeded(id: self.document.id)
                    } catch {
                        completion(nil, false, error)
                        return nil
                    }
                }
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
    
    private var fileTypeBadge: some View {
        let colors = DesignTokens.FileTypeColor.gradient(for: document.documentType)
        let iconName = DesignTokens.FileTypeColor.icon(for: document.documentType)
        
        return ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Corner.sm)
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 34)
            
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var statusPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)
            Text(statusText)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(4)
    }
    
    private var tagDots: some View {
        HStack(spacing: 3) {
            ForEach(Array(document.tags.prefix(3)), id: \.self) { tag in
                Circle()
                    .fill(tagColor(for: tag))
                    .frame(width: 5, height: 5)
            }
            if document.tags.count > 3 {
                Text("+\(document.tags.count - 3)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var staticIndicators: some View {
        HStack(spacing: 6) {
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
    }
    
    private var hoverActions: some View {
        HStack(spacing: 4) {
            Button(action: { viewModel.openDocument(document: document) }) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .disabled(document.isLocked)
            .help("Open")
            
            if document.isAvailable {
                Button(action: { viewModel.checkOut(document: document) }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Check Out")
            }
            
            if document.isCheckedOut && document.checkedOutBy == NSFullUserName() {
                Button(action: { viewModel.quickCheckIn(document: document) }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Check In")
            }
            
            Button(action: { viewModel.startRename(document) }) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Rename")
        }
    }
    
    private var statusColor: Color {
        switch document.status {
        case .available: return DesignTokens.Colors.statusAvailable
        case .checkedOut: return DesignTokens.Colors.statusCheckedOut
        case .locked: return DesignTokens.Colors.statusLocked
        }
    }
    
    private var statusText: String {
        switch document.status {
        case .available: return "Available"
        case .checkedOut:
            return document.checkedOutBy == NSFullUserName() ? "Checked out" : "Checked out"
        case .locked: return "Locked"
        }
    }
    
    private func tagColor(for tag: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .cyan]
        let hash = tag.hashValue
        return colors[abs(hash) % colors.count]
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
