import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage("autoCheckInOnAppClose") private var autoCheckInOnAppClose = true
    @AppStorage("notifyOnDocumentChange") private var notifyOnDocumentChange = true
    @AppStorage("autoVersionOnSave") private var autoVersionOnSave = true
    @AppStorage("storageLocation") private var storageLocation = "default"
    @AppStorage("maxVersionsToKeep") private var maxVersionsToKeep = 10

    @State private var showEraseConfirmation = false
    @State private var showNewDatabaseConfirmation = false
    @State private var statusMessage: String?
    @State private var showStatus = false

    private let dbManager = DatabaseManager.shared
    private let fileManager = FileManager.default

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "pawprint.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("PandyDoc Settings")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            Divider()
            TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            printerSettings
                .tabItem {
                    Label("Printer", systemImage: "printer")
                }

            versioningSettings
                .tabItem {
                    Label("Versioning", systemImage: "clock.arrow.circlepath")
                }

            databaseSettings
                .tabItem {
                    Label("Database", systemImage: "externaldrive")
                }
        }
        .frame(width: 480, height: 340)
        }
        .alert("Erase All Data", isPresented: $showEraseConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Erase", role: .destructive) { eraseAllData() }
        } message: {
            Text("This will permanently delete all documents, versions, and folders. This action cannot be undone.")
        }
        .alert("Create New Database", isPresented: $showNewDatabaseConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Create New", role: .destructive) { eraseAllData() }
        } message: {
            Text("This will erase the current database and create a new empty one. All existing data will be lost.")
        }
        .alert(statusMessage ?? "", isPresented: $showStatus) {
            Button("OK", role: .cancel) {}
        }
    }
    
    private var generalSettings: some View {
        Form {
            Section("Behavior") {
                Toggle("Auto check-in when editing app closes", isOn: $autoCheckInOnAppClose)
                Toggle("Notify on document changes", isOn: $notifyOnDocumentChange)
            }
            
            Section("Storage") {
                Picker("Storage Location", selection: $storageLocation) {
                    Text("Default (~/Library/Application Support/PandyDoc)").tag("default")
                    Text("Custom...").tag("custom")
                }
            }

            Section("Folder Access") {
                if FolderAccessManager.shared.grantedFolders.isEmpty {
                    Text("No folders have been granted access. Import documents to grant access on demand.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(FolderAccessManager.shared.grantedFolders, id: \.self) { folder in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.accentColor)
                            Text(folder.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button(action: {
                                FolderAccessManager.shared.revokeAccess(for: folder)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Revoke access")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var printerSettings: some View {
        Form {
            Section("PandyDoc Printer") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "printer")
                            .font(.title2)
                        Text("PandyDoc PDF")
                            .font(.headline)
                    }
                    
                    Text("Print to PandyDoc from any application to save documents directly to the document management system.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Open Printer Setup") {
                        NotificationCenter.default.post(name: .showPrinterSetup, object: nil)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var versioningSettings: some View {
        Form {
            Section("Version Control") {
                Toggle("Auto-version on save", isOn: $autoVersionOnSave)
                
                HStack {
                    Text("Maximum versions to keep")
                    Spacer()
                    TextField("10", value: $maxVersionsToKeep, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                }
            }
            
            Section("Version Notes") {
                Toggle("Require notes on check-in", isOn: .constant(false))
                Toggle("Auto-generate version notes", isOn: .constant(true))
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var databaseSettings: some View {
        Form {
            Section("Database Location") {
                HStack {
                    Text(dbManager.databaseURL.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Spacer()
                    Button(action: { revealInFinder() }) {
                        Image(systemName: "arrow.right.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Reveal in Finder")
                }
            }

            Section("Actions") {
                Button(action: { backupDatabase() }) {
                    Label("Back Up Database...", systemImage: "arrow.up.doc")
                }

                Button(action: { showNewDatabaseConfirmation = true }) {
                    Label("Create New Database", systemImage: "plus.rectangle")
                }

                Button(action: { showEraseConfirmation = true }) {
                    Label("Erase All Data", systemImage: "trash")
                }
                .tint(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func backupDatabase() {
        let savePanel = NSSavePanel()
        savePanel.title = "Back Up Database"
        savePanel.nameFieldStringValue = "PandyDoc Backup \(dateString())"
        savePanel.prompt = "Back Up"
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            guard response == .OK, let destURL = savePanel.url else { return }
            do {
                dbManager.checkpoint()
                let backupDir = destURL
                try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)

                if fileManager.fileExists(atPath: dbManager.databaseURL.path) {
                    let dbDest = backupDir.appendingPathComponent("pandydoc.sqlite3")
                    if fileManager.fileExists(atPath: dbDest.path) {
                        try fileManager.removeItem(at: dbDest)
                    }
                    try fileManager.copyItem(at: dbManager.databaseURL, to: dbDest)
                }

                let documentsSrc = dbManager.documentsURL
                if fileManager.fileExists(atPath: documentsSrc.path) {
                    let documentsDest = backupDir.appendingPathComponent("Documents", isDirectory: true)
                    if fileManager.fileExists(atPath: documentsDest.path) {
                        try fileManager.removeItem(at: documentsDest)
                    }
                    try fileManager.copyItem(at: documentsSrc, to: documentsDest)
                }

                let versionsSrc = dbManager.versionsURL
                if fileManager.fileExists(atPath: versionsSrc.path) {
                    let versionsDest = backupDir.appendingPathComponent("Versions", isDirectory: true)
                    if fileManager.fileExists(atPath: versionsDest.path) {
                        try fileManager.removeItem(at: versionsDest)
                    }
                    try fileManager.copyItem(at: versionsSrc, to: versionsDest)
                }

                statusMessage = "Database backed up successfully."
                showStatus = true
            } catch {
                statusMessage = "Backup failed: \(error.localizedDescription)"
                showStatus = true
            }
        }
    }

    private func eraseAllData() {
        do {
            try dbManager.eraseAll()
            NotificationCenter.default.post(name: .documentReceived, object: nil)
            statusMessage = "All data has been erased. A new empty database has been created."
            showStatus = true
        } catch {
            statusMessage = "Failed to erase data: \(error.localizedDescription)"
            showStatus = true
        }
    }

    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([dbManager.databaseURL])
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

extension Notification.Name {
    static let showPrinterSetup = Notification.Name("showPrinterSetup")
}
