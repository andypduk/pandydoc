import SwiftUI

struct GoogleDriveBrowserView: View {
    @StateObject private var viewModel: GoogleDriveBrowserViewModel
    @Environment(\.dismiss) private var dismiss

    init(documentVM: DocumentListViewModel) {
        _viewModel = StateObject(wrappedValue: GoogleDriveBrowserViewModel(documentVM: documentVM))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !GoogleDriveClient.shared.isAuthenticated {
                    notAuthenticatedView
                } else {
                    browserContent
                }
            }
            .frame(width: 500, height: 450)
            .navigationTitle("Import from Google Drive")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if GoogleDriveClient.shared.isAuthenticated {
                        Button("Import \(viewModel.selectedItems.count) item\(viewModel.selectedItems.count == 1 ? "" : "s")") {
                            viewModel.importSelected()
                        }
                        .disabled(viewModel.selectedItems.isEmpty || viewModel.isLoading || viewModel.downloadProgress != nil)
                        .buttonStyle(.borderedProminent)
                    }
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
            .task {
                viewModel.loadItems()
            }
        }
    }

    private var notAuthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Sign in to Google Drive to browse and import files")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Sign In") {
                Task {
                    do {
                        try await GoogleDriveClient.shared.authenticate()
                        viewModel.loadItems()
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var browserContent: some View {
        VStack(spacing: 0) {
            if !viewModel.folderPath.isEmpty {
                breadcrumbBar
                Divider()
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.items.isEmpty {
                ContentUnavailableView("No items", systemImage: "folder", description: Text("This folder is empty"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                fileList
            }

            if viewModel.downloadProgress != nil {
                Divider()
                downloadProgressOverlay
            }
        }
    }

    private var breadcrumbBar: some View {
        HStack {
            Button("Root") {
                viewModel.navigateUp()
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            ForEach(Array(viewModel.folderPath.enumerated()), id: \.element.id) { index, folder in
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button(folder.name) {
                    while viewModel.folderPath.count > index + 1 {
                        viewModel.navigateUp()
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var fileList: some View {
        List {
            ForEach(viewModel.items) { item in
                HStack(spacing: 8) {
                    Toggle("", isOn: Binding(
                        get: { viewModel.selectedItems.contains(item.id) },
                        set: { _ in viewModel.toggleSelection(item) }
                    ))
                    .labelsHidden()

                    Image(systemName: item.isFolder ? "folder.fill" : fileIcon(for: item))
                        .foregroundColor(item.isFolder ? .accentColor : .secondary)
                        .frame(width: 20)

                    Text(item.name)
                        .lineLimit(1)

                    Spacer()

                    if let size = item.size, !item.isFolder {
                        Text(sizeFormatted(size))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if item.isFolder {
                        viewModel.navigateTo(folder: item)
                    } else {
                        viewModel.toggleSelection(item)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private var downloadProgressOverlay: some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.documentVM.importProgress ?? 0)
                .progressViewStyle(.linear)
                .frame(width: 280)
            Text("Importing \(viewModel.documentVM.importCurrentFile) of \(viewModel.documentVM.importTotalFiles) files (\(Int((viewModel.documentVM.importProgress ?? 0) * 100))%)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
    }

    private func fileIcon(for item: GDriveItem) -> String {
        if item.mimeType.contains("pdf") { return "doc.richtext.fill" }
        if item.mimeType.contains("image") { return "photo.fill" }
        if item.mimeType.contains("word") || item.mimeType.contains("document") { return "doc.text.fill" }
        if item.mimeType.contains("spreadsheet") { return "tablecells.fill" }
        if item.mimeType.contains("presentation") { return "play.rectangle.fill" }
        return "doc.fill"
    }

    private func sizeFormatted(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
