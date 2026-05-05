import SwiftUI

@main
struct DocManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Document...") {
                    NotificationCenter.default.post(name: .importDocument, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command])
            }
            
            CommandGroup(after: .newItem) {
                Button("Check In Document...") {
                    NotificationCenter.default.post(name: .checkInDocument, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}

extension Notification.Name {
    static let importDocument = Notification.Name("importDocument")
    static let checkInDocument = Notification.Name("checkInDocument")
}
