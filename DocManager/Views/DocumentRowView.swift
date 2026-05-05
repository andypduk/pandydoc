import SwiftUI

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
            }
            
            Spacer()
            
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
        }
        .padding(.vertical, 2)
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
            Button(action: { viewModel.checkIn(document: document) }) {
                Label("Check In", systemImage: "square.and.arrow.up")
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
        
        Button(action: { viewModel.openDocument(document: document) }) {
            Label("Open", systemImage: "arrow.up.right.square")
        }
        
        Button(action: { viewModel.showVersions(for: document) }) {
            Label("Version History", systemImage: "clock.arrow.circlepath")
        }
        
        Divider()
        
        Button(role: .destructive, action: { viewModel.deleteDocument(document: document) }) {
            Label("Delete", systemImage: "trash")
        }
    }
}
