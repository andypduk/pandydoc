import SwiftUI

@main
struct DocManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showAbout = false
    @State private var apiServerStarted = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $showAbout) {
                    AboutView()
                }
                .onAppear {
                    if !apiServerStarted {
                        apiServerStarted = true
                        Task { @MainActor in
                            try? await APIServer.shared.start()
                        }
                    }
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Document...") {
                    NotificationCenter.default.post(name: .importDocument, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command])

                Button("Import Folder...") {
                    let panel = NSOpenPanel()
                    panel.title = "Import Folder"
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.begin { response in
                        if response == .OK, let url = panel.url {
                            NotificationCenter.default.post(name: .importFolder, object: nil, userInfo: ["url": url])
                        }
                    }
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }

            CommandGroup(after: .newItem) {
                Button("Check In Document...") {
                    NotificationCenter.default.post(name: .checkInDocument, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button("Printer Setup...") {
                    NotificationCenter.default.post(name: .showPrinterSetup, object: nil)
                }
            }

            CommandGroup(replacing: .sidebar) {
                Button("Show Sidebar") {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                }
                .keyboardShortcut("0", modifiers: [.command, .option])
            }

            CommandGroup(after: .windowSize) {
                Button("Show Inbox") {
                    NotificationCenter.default.post(name: .navigateToInbox, object: nil)
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button("Show Flagged") {
                    NotificationCenter.default.post(name: .navigateToFlagged, object: nil)
                }
                .keyboardShortcut("4", modifiers: [.command])

                Button("Show All Documents") {
                    NotificationCenter.default.post(name: .navigateToAllDocuments, object: nil)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Show Templates") {
                    NotificationCenter.default.post(name: .navigateToTemplates, object: nil)
                }
                .keyboardShortcut("2", modifiers: [.command])
            }

            CommandGroup(replacing: .help) {
                Button("PandyDoc Help") {
                    NotificationCenter.default.post(name: .showHelpWithTab, object: nil, userInfo: ["tab": HelpTab.gettingStarted])
                }
                .keyboardShortcut("?", modifiers: [.command])

                Divider()

                Button("Getting Started") {
                    NotificationCenter.default.post(name: .showHelpWithTab, object: nil, userInfo: ["tab": HelpTab.gettingStarted])
                }

                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .showHelpWithTab, object: nil, userInfo: ["tab": HelpTab.advanced])
                }

                Divider()

                Button("About PandyDoc") {
                    showAbout = true
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}

extension Notification.Name {
    static let importDocument = Notification.Name("importDocument")
    static let importFolder = Notification.Name("importFolder")
    static let checkInDocument = Notification.Name("checkInDocument")
    static let showHelp = Notification.Name("showHelp")
    static let showHelpWithTab = Notification.Name("showHelpWithTab")
    static let navigateToAllDocuments = Notification.Name("navigateToAllDocuments")
    static let navigateToTemplates = Notification.Name("navigateToTemplates")
    static let navigateToInbox = Notification.Name("navigateToInbox")
    static let navigateToFlagged = Notification.Name("navigateToFlagged")
}
