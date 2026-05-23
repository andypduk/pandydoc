import SwiftUI

struct DocumentDetailView: View {
    let document: Document
    @ObservedObject var viewModel: DocumentListViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                Divider()
                detailsSection
                Divider()
                actionsSection
                Divider()
                tagsSection
            }
            .padding()
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            documentTypeIcon
                .font(.system(size: 48))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 12) {
                    statusBadge
                    Text(document.fileExtension.uppercased())
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            versionIndicator
        }
    }
    
    private var documentTypeIcon: some View {
        Group {
            switch document.documentType {
            case .pdf: Image(systemName: "doc.richtext")
            case .docx: Image(systemName: "doc.text")
            case .xlsx: Image(systemName: "tablecells")
            case .txt: Image(systemName: "doc.plaintext")
            case .rtf: Image(systemName: "doc.richtext")
            case .pages: Image(systemName: "doc.text.fill")
            case .numbers: Image(systemName: "tablecells.fill")
            case .key: Image(systemName: "play.rectangle.fill")
            case .other: Image(systemName: "doc")
            }
        }
        .foregroundColor(iconColor)
    }
    
    private var iconColor: Color {
        switch document.documentType {
        case .pdf: return .red
        case .docx, .pages: return .blue
        case .xlsx, .numbers: return .green
        case .key: return .orange
        default: return .gray
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.getStatusColor(document.status))
                .frame(width: 8, height: 8)
            
            Text(document.status.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(viewModel.getStatusColor(document.status).opacity(0.15))
        .cornerRadius(12)
    }
    
    private var versionIndicator: some View {
        VStack {
            Text("v\(document.currentVersion)")
                .font(.title2)
                .fontWeight(.bold)
            Text("Version")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
            
            DetailRow(label: "File Name", value: document.fileName)
            DetailRow(label: "File Size", value: formatFileSize(document.fileSize))
            DetailRow(label: "Created", value: formatDate(document.createdAt))
            DetailRow(label: "Last Modified", value: formatDate(document.updatedAt))
            
            if let checkedOutBy = document.checkedOutBy,
               let checkedOutAt = document.checkedOutAt {
                DetailRow(label: "Checked Out By", value: checkedOutBy)
                DetailRow(label: "Checked Out At", value: formatDate(checkedOutAt))
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
            
            VStack(spacing: 8) {
                if document.isAvailable {
                    HStack(spacing: 8) {
                        Button(action: { viewModel.checkOut(document: document) }) {
                            Label("Check Out & Edit", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        
                        Button(action: { viewModel.lockDocument(document: document) }) {
                            Label("Lock", systemImage: "lock")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                if document.isCheckedOut && document.checkedOutBy == NSFullUserName() {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Button(action: { viewModel.quickCheckIn(document: document) }) {
                                Label("Check In", systemImage: "checkmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            
                            Button(action: { viewModel.checkInWithNotes(document: document) }) {
                                Label("Notes...", systemImage: "text.badge.checkmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        HStack(spacing: 8) {
                            Button(action: { viewModel.saveWorkingCopy(document: document) }) {
                                Label("Save Working Copy", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button(action: { viewModel.discardCheckOut(document: document) }) {
                                Label("Discard Changes", systemImage: "xmark.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                }
                
                if document.isLocked && document.checkedOutBy == NSFullUserName() {
                    Button(action: { viewModel.unlockDocument(document: document) }) {
                        Label("Unlock", systemImage: "lock.open")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                HStack(spacing: 8) {
                    Button(action: { viewModel.openDocument(document: document) }) {
                        Label("Open", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { viewModel.showVersions(for: document) }) {
                        Label("Versions", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)
            
            if document.tags.isEmpty {
                Text("No tags")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                FlowLayout {
                    ForEach(document.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let result = FlowResult(subviews: subviews, proposal: proposal, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let result = FlowResult(subviews: subviews, proposal: proposal, spacing: spacing)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), anchor: .topLeading, proposal: proposal)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(subviews: Subviews, proposal: ProposedViewSize, spacing: CGFloat) {
            let maxWidth = proposal.width ?? .infinity
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
