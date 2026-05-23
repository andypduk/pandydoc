import SwiftUI

@main
struct DocManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
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
                    NotificationCenter.default.post(name: .showHelp, object: nil)
                }
                .keyboardShortcut("?", modifiers: [.command])

                Divider()

                Button("Getting Started") {
                    NotificationCenter.default.post(name: .showGettingStarted, object: nil)
                }

                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .showShortcuts, object: nil)
                }

                Divider()

                Button("About PandyDoc") {
                    NSApp.orderFrontStandardAboutPanel(nil)
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
    static let showGettingStarted = Notification.Name("showGettingStarted")
    static let showShortcuts = Notification.Name("showShortcuts")
    static let navigateToAllDocuments = Notification.Name("navigateToAllDocuments")
    static let navigateToTemplates = Notification.Name("navigateToTemplates")
}
