import SwiftUI

struct SettingsView: View {
    @AppStorage("autoCheckInOnAppClose") private var autoCheckInOnAppClose = true
    @AppStorage("notifyOnDocumentChange") private var notifyOnDocumentChange = true
    @AppStorage("autoVersionOnSave") private var autoVersionOnSave = true
    @AppStorage("storageLocation") private var storageLocation = "default"
    
    var body: some View {
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
        }
        .frame(width: 450, height: 300)
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
                    TextField("10", value: .constant(10), formatter: NumberFormatter())
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
}

extension Notification.Name {
    static let showPrinterSetup = Notification.Name("showPrinterSetup")
}
