import AppKit

@main
struct SaveToPandyDocApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let fileManager = FileManager.default
        let args = CommandLine.arguments.dropFirst()

        let homeDir = fileManager.homeDirectoryForCurrentUser
        let incomingDir = homeDir.appendingPathComponent("Library/Application Support/PandyDoc/Incoming")

        try? fileManager.createDirectory(at: incomingDir, withIntermediateDirectories: true)

        for arg in args {
            let sourceURL = URL(fileURLWithPath: arg)
            guard sourceURL.pathExtension.lowercased() == "pdf" else { continue }

            let fileName = sourceURL.lastPathComponent
            let uuid = UUID().uuidString
            let destURL = incomingDir.appendingPathComponent("\(uuid)-\(fileName)")

            do {
                try fileManager.copyItem(at: sourceURL, to: destURL)
            } catch {
                print("SaveToPandyDoc: failed to copy \(arg): \(error)")
            }
        }

        NSApp.terminate(nil)
    }
}
