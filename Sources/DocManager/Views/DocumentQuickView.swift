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
            toolbar
            Divider()
            documentPreview
            Divider()
            statusBar
        }
        .onAppear {
            loadDocument()
        }
        .onChange(of: viewModel.selectedDocument?.id) { _, _ in
            loadDocument()
        }
        .onChange(of: viewModel.documentRefreshToken) { _, _ in
            loadDocument()
        }
        .alert("Conversion Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            if pdfDocument != nil || previewImage != nil {
                Button(action: zoomIn) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .disabled(zoomLevel >= 3.0)
                .help("Zoom In")

                Button(action: zoomOut) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .disabled(zoomLevel <= 0.25)
                .help("Zoom Out")

                Button(action: { zoomLevel = 1.0 }) {
                    Image(systemName: "1.magnifyingglass")
                }
                .disabled(zoomLevel == 1.0)
                .help("Actual Size")
            }

            Spacer()

            if pdfDocument != nil && totalPages > 1 {
                HStack(spacing: 4) {
                    Button(action: { if currentPage > 1 { currentPage -= 1 } }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentPage <= 1)

                    Text("Page \(currentPage) of \(totalPages)")
                        .font(.caption)
                        .monospacedDigit()

                    Button(action: { if currentPage < totalPages { currentPage += 1 } }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentPage >= totalPages)
                }
            }

            Spacer()

            if !isQuickLookable && !isPDF {
                Button(action: convertToPDF) {
                    Label("Convert to PDF", systemImage: "doc.richtext")
                }
                .disabled(isConverting)
                .help("Convert document to PDF for preview")
            }

            Button(action: {
                let url = URL(fileURLWithPath: document.filePath)
                NSWorkspace.shared.open(url)
            }) {
                Image(systemName: "arrow.up.right.square")
            }
            .help("Open in Default App")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var documentPreview: some View {
        Group {
            if isConverting {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Generating preview...")
                        .font(.caption)
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
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Preview not available")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Text(document.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(formatFileSize(document.fileSize))
                .font(.caption)
                .foregroundColor(.secondary)

            Text("•")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("v\(document.currentVersion)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("•")
                .font(.caption)
                .foregroundColor(.secondary)

            Circle()
                .fill(viewModel.getStatusColor(document.status))
                .frame(width: 8, height: 8)

            Text(document.status.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.delegate = context.coordinator
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit * zoomLevel
        if let page = document.page(at: currentPage - 1) {
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
