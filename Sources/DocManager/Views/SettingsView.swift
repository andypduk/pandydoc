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
    @State private var showBackupSheet = false
    @State private var isICloudAvailable = false
    @State private var showApiKey = false
    @State private var showRegenerateAlert = false
    @State private var apiPort: Int = {
        let stored = UserDefaults.standard.integer(forKey: "apiPort")
        return stored == 0 ? 8080 : stored
    }()

    private let dbManager = DatabaseManager.shared
    private let fileManager = FileManager.default

    init() {
        isICloudAvailable = FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
    }

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

            apiSettings
                .tabItem {
                    Label("API", systemImage: "network")
                }

            googleDriveSettings
                .tabItem {
                    Label("Google Drive", systemImage: "cloud.fill")
                }
        }
        .frame(width: 480, height: 420)
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

            Section("Database Size") {
                HStack {
                    Text("Current size")
                    Spacer()
                    Text(formatSize(dbManager.databaseSize()))
                        .foregroundColor(.secondary)
                }
            }

            Section("Actions") {
                Button(action: { compressDatabase() }) {
                    Label("Compress Database", systemImage: "arrow.down.bin")
                }

                Button(action: { showBackupSheet = true }) {
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
        .sheet(isPresented: $showBackupSheet) {
            BackupSheet(isICloudAvailable: isICloudAvailable, statusMessage: $statusMessage, showStatus: $showStatus)
        }
    }

    var apiSettings: some View {
        Form {
            Section("API Key") {
                HStack {
                    Text(showApiKey ? APIKeyManager.shared.apiKey : String(repeating: "•", count: 64))
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Button(showApiKey ? "Hide" : "Show") { showApiKey.toggle() }
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(APIKeyManager.shared.apiKey, forType: .string)
                    }
                }

                Button("Regenerate Key", role: .destructive) { showRegenerateAlert = true }
                    .alert("Regenerate API Key?", isPresented: $showRegenerateAlert) {
                        Button("Regenerate", role: .destructive) { _ = APIKeyManager.shared.regenerateKey(); showApiKey = false }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("The current key will stop working immediately.")
                    }
            }

            Section("Server") {
                HStack {
                    Text("Status:")
                    Text(APIServer.shared.isRunning ? "Running" : "Stopped")
                        .foregroundColor(APIServer.shared.isRunning ? .green : .red)
                    Spacer()
                    Button(APIServer.shared.isRunning ? "Stop" : "Start") {
                        Task { @MainActor in
                            if APIServer.shared.isRunning {
                                await APIServer.shared.stop()
                            } else {
                                try? await APIServer.shared.start()
                            }
                        }
                    }
                }

                HStack {
                    Text("Port:")
                    TextField("Port", value: $apiPort, formatter: NumberFormatter())
                        .frame(width: 80)
                        .onChange(of: apiPort) { UserDefaults.standard.set(apiPort, forKey: "apiPort") }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var googleDriveSettings: some View {
        Form {
            Section("Importing from Google Drive") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("To import documents from Google Drive, use the Google Drive for Desktop app.")
                        .font(.body)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. Install Google Drive for Desktop from google.com/drive/download")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("2. Sign in and let it sync your Drive to your Mac")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("3. In PandyDoc, use Import → select files or folders from your synced Google Drive folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Link("Download Google Drive for Desktop", destination: URL(string: "https://www.google.com/drive/download/")!)
                        .font(.caption)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func compressDatabase() {
        do {
            let beforeSize = dbManager.databaseSize()
            try dbManager.vacuum()
            let afterSize = dbManager.databaseSize()
            let saved = beforeSize - afterSize
            if saved > 0 {
                statusMessage = "Database compressed. Freed \(formatSize(saved))."
            } else {
                statusMessage = "Database is already optimized. No space freed."
            }
            showStatus = true
        } catch {
            statusMessage = "Compression failed: \(error.localizedDescription)"
            showStatus = true
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
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
}

struct BackupSheet: View {
    let isICloudAvailable: Bool
    @Binding var statusMessage: String?
    @Binding var showStatus: Bool
    @Environment(\.dismiss) private var dismiss
    
    @State private var isBackingUp = false
    @State private var backupProgress: String = ""
    
    private let dbManager = DatabaseManager.shared
    private let fileManager = FileManager.default
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "externaldrive.fill.badge.arrow.up")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Back Up Database")
                    .font(.headline)
                Spacer()
            }
            
            Text("Choose where to save your backup. The backup includes the database, documents, and version history.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            VStack(spacing: 12) {
                Button(action: { backupToLocalLocation() }) {
                    Label("Choose Location...", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                if isICloudAvailable {
                    Button(action: { backupToICloud() }) {
                        Label("Back Up to iCloud Drive", systemImage: "icloud")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } else {
                    Button(action: {}) {
                        Label("iCloud Not Configured", systemImage: "icloud.slash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(true)
                    
                    Text("Enable iCloud Drive in System Settings > Apple ID > iCloud to back up here.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if isBackingUp {
                ProgressView(backupProgress)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
        }
        .padding()
        .frame(width: 360, height: isICloudAvailable ? 300 : 340)
        .alert(statusMessage ?? "", isPresented: $showStatus) {
            Button("OK") { dismiss() }
        }
    }
    
    private func backupToLocalLocation() {
        let savePanel = NSSavePanel()
        savePanel.title = "Choose Backup Location"
        savePanel.nameFieldStringValue = "PandyDoc Backup \(dateString())"
        savePanel.prompt = "Back Up"
        savePanel.canCreateDirectories = true
        savePanel.canSelectHiddenExtension = true
        savePanel.isExtensionHidden = false
        
        savePanel.begin { response in
            guard response == .OK, let destURL = savePanel.url else { return }
            performBackup(to: destURL)
        }
    }
    
    private func backupToICloud() {
        isBackingUp = true
        backupProgress = "Backing up to iCloud Drive..."
        
        Task.detached {
            do {
                let result = try dbManager.backupToiCloudDrive()
                await MainActor.run {
                    isBackingUp = false
                    if let result {
                        statusMessage = "Backed up to iCloud Drive: \(result.path)"
                    } else {
                        statusMessage = "iCloud Drive is not available."
                    }
                    showStatus = true
                }
            } catch {
                await MainActor.run {
                    isBackingUp = false
                    statusMessage = "Backup failed: \(error.localizedDescription)"
                    showStatus = true
                }
            }
        }
    }
    
    private func performBackup(to destURL: URL) {
        isBackingUp = true
        backupProgress = "Creating backup..."
        
        Task.detached {
            do {
                try dbManager.liveBackup(to: destURL)
                await MainActor.run {
                    isBackingUp = false
                    statusMessage = "Database backed up successfully."
                    showStatus = true
                }
            } catch {
                await MainActor.run {
                    isBackingUp = false
                    statusMessage = "Backup failed: \(error.localizedDescription)"
                    showStatus = true
                }
            }
        }
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
