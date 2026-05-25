import SwiftUI
import PDFKit
import AppKit
import QuickLookUI

struct DocumentQuickView: View {
    @ObservedObject var viewModel: DocumentListViewModel
    @State private var zoomLevel: CGFloat = 1.0
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1
    @State private var pdfDocument: PDFDocument?
    @State private var previewURL: URL?
    @State private var previewImage: NSImage?
    @State private var isConverting = false
    @State private var errorMessage: String?

    private var document: Document {
        viewModel.selectedDocument ?? Document(
            id: UUID(),
            name: "",
            fileName: "",
            fileExtension: "",
            documentType: .other,
            status: .available,
            checkedOutBy: nil,
            checkedOutAt: nil,
            currentVersion: 0,
            fileSize: 0,
            createdAt: Date(),
            updatedAt: Date(),
            tags: [],
            notes: "",
            parentID: nil,
            filePath: "",
            thumbnailPath: nil,
            protected: false
        )
    }

    private var isPDF: Bool {
        document.documentType == .pdf
    }

    private var isQuickLookable: Bool {
        let types: Set<DocumentType> = [.pages, .numbers, .key, .txt, .rtf, .xlsx, .docx, .pptx]
        return types.contains(document.documentType)
    }

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

    @State private var newTagText = ""

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Tags")
                .font(DesignTokens.Typography.labelStyle())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            if !document.tags.isEmpty {
                FlowLayout(spacing: DesignTokens.Spacing.xs) {
                    ForEach(document.tags, id: \.self) { tag in
                        RefinedTagChip(tag: tag) {
                            viewModel.removeTag(from: document, tag: tag)
                        }
                    }
                }
            }
            
            HStack(spacing: DesignTokens.Spacing.xs) {
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
            .padding(DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Corner.md)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundColor(Color.black.opacity(0.15))
            )
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private var toolbar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if pdfDocument != nil || previewImage != nil {
                pillButton(icon: "plus.magnifyingglass", action: zoomIn, disabled: zoomLevel >= 3.0, help: "Zoom In")
                pillButton(icon: "minus.magnifyingglass", action: zoomOut, disabled: zoomLevel <= 0.25, help: "Zoom Out")
                pillButton(icon: "1.magnifyingglass", action: { zoomLevel = 1.0 }, disabled: zoomLevel == 1.0, help: "Actual Size")
            }

            Spacer()

            if pdfDocument != nil && totalPages > 1 {
                HStack(spacing: DesignTokens.Spacing.xs) {
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
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
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
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(DesignTokens.Corner.lg)
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }

    private var documentPreview: some View {
        Group {
            if isConverting {
                VStack(spacing: DesignTokens.Spacing.sm) {
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
                VStack(spacing: DesignTokens.Spacing.lg) {
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
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Corner.lg)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private var headerSection: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
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
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(document.name)
                    .font(DesignTokens.Typography.titleStyle())
                    .lineLimit(1)
                
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(DesignTokens.Typography.metadataStyle())
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
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
            if document.checkedOutBy == NSFullUserName() {
                return "Checked out by you"
            }
            return "Checked out"
        case .locked: return "Locked"
        }
    }

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
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func loadDocument() {
        zoomLevel = 1.0
        currentPage = 1
        totalPages = 1
        pdfDocument = nil
        previewURL = nil
        previewImage = nil
        isConverting = false

        let url = URL(fileURLWithPath: document.filePath)
        guard FileManager.default.fileExists(atPath: document.filePath) else { return }

        if isPDF {
            if let pdf = PDFDocument(url: url) {
                pdfDocument = pdf
                totalPages = pdf.pageCount
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    fitToWidth()
                }
            }
        } else if isQuickLookable {
            previewURL = url
        } else {
            previewURL = url
        }
    }

    private func convertToPDF() {
        isConverting = true
        let url = URL(fileURLWithPath: document.filePath)
        let generator = PDFPreviewGenerator.shared

        print("QuickView: Starting manual PDF conversion for \(document.filePath)")
        print("QuickView: File extension = \(url.pathExtension)")

        Task {
            let success = await generator.generatePDF(from: url, documentID: document.id)
            print("QuickView: PDF conversion result: \(success)")

            await MainActor.run {
                isConverting = false
                if success, let pdf = PDFDocument(url: generator.cachedPDFURL(for: document.id)) {
                    print("QuickView: Loaded converted PDF with \(pdf.pageCount) pages")
                    pdfDocument = pdf
                    totalPages = pdf.pageCount
                    previewURL = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        fitToWidth()
                    }
                } else {
                    print("QuickView: Conversion failed or PDF not loadable")
                    errorMessage = "Failed to convert document to PDF"
                }
            }
        }
    }

    private func zoomIn() {
        withAnimation(.easeOut(duration: 0.15)) {
            zoomLevel = min(zoomLevel * 1.25, 3.0)
        }
    }

    private func zoomOut() {
        withAnimation(.easeOut(duration: 0.15)) {
            zoomLevel = max(zoomLevel / 1.25, 0.25)
        }
    }

    private func fitToWidth() {
        zoomLevel = 1.0
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument
    let zoomLevel: CGFloat
    @Binding var currentPage: Int

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = false
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.delegate = context.coordinator
        pdfView.minScaleFactor = 0.1
        pdfView.maxScaleFactor = 5.0
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        guard let page = document.page(at: max(0, currentPage - 1)) else { return }
        let pageBounds = page.bounds(for: .mediaBox)
        let viewBounds = pdfView.bounds
        if viewBounds.width > 0 && pageBounds.width > 0 {
            let fitWidthScale = viewBounds.width / pageBounds.width
            pdfView.scaleFactor = fitWidthScale * zoomLevel
        }
        if pdfView.currentPage != page {
            pdfView.go(to: page)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFKitView

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        func pdfViewPageChanged(_ notification: Notification) {
            if let pdfView = notification.object as? PDFView,
               let currentPage = pdfView.currentPage {
                let pageIndex = parent.document.index(for: currentPage)
                DispatchQueue.main.async {
                    self.parent.currentPage = pageIndex + 1
                }
            }
        }
    }
}

struct QuickLookView: NSViewRepresentable {
    let fileURL: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let previewView = QLPreviewView()
        previewView.autostarts = true
        previewView.previewItem = fileURL as NSURL
        return previewView
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = fileURL as NSURL
    }
}

struct RefinedTagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
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
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.tagChipBackground)
        .cornerRadius(DesignTokens.Corner.xl)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: position, anchor: .topLeading, proposal: proposal)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(proposal)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        let finalHeight = currentY + lineHeight
        return (CGSize(width: maxWidth, height: finalHeight), positions)
    }
}
