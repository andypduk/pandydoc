import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DocumentListViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showImportSheet = false
    @State private var showPrinterSetup = false
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detailView
        }
        .frame(minWidth: 900, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showImportSheet = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .help("Import document")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showPrinterSetup = true }) {
                    Label("Printer Setup", systemImage: "printer")
                }
                .help("Setup PandyDoc printer")
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: { viewModel.refreshDocuments() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
        .fileImporter(
            isPresented: $showImportSheet,
            allowedContentTypes: [.pdf, .data],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    _ = url.startAccessingSecurityScopedResource()
                    viewModel.importDocument(fileURL: url)
                    url.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
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
        .onAppear {
            try? DocumentStorage.shared.initializeStorage()
            try? PDFPrinterService.shared.initialize()
        }
    }
    
    private var sidebar: some View {
        List(viewModel.documents, id: \.id, selection: $viewModel.selectedDocument) { document in
            DocumentRowView(document: document, viewModel: viewModel)
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 250)
        .searchable(text: $viewModel.searchQuery, prompt: "Search documents")
        .onChange(of: viewModel.searchQuery) { _, _ in
            viewModel.searchDocuments()
        }
    }
    
    private var detailView: some View {
        Group {
            if let document = viewModel.selectedDocument {
                DocumentDetailView(document: document, viewModel: viewModel)
            } else {
                ContentUnavailableView(
                    "No Document Selected",
                    systemImage: "doc",
                    description: Text("Select a document from the sidebar or import a new one")
                )
            }
        }
    }
}
