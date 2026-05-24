import SwiftUI

struct AdvancedTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HelpSectionHeader(
                    title: "Advanced Features",
                    subtitle: "Settings, backups, file watching, keyboard shortcuts, and troubleshooting."
                )
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    QuickRefCard(title: "Settings", description: "Configure PandyDoc preferences.", icon: "gearshape") {}
                    QuickRefCard(title: "Keyboard Shortcuts", description: "Quick reference for all shortcuts.", icon: "command") {}
                    QuickRefCard(title: "iCloud Backup", description: "Back up your database to iCloud.", icon: "icloud") {}
                    QuickRefCard(title: "Troubleshooting", description: "Fix common issues.", icon: "wrench.and.screwdriver") {}
                }
                
                Divider()
                
                HelpSectionHeader(title: "Step-by-Step Guides", subtitle: "")
                
                WalkthroughSection(
                    title: "Keyboard Shortcuts",
                    steps: [
                        "**Cmd+I** — Import Document",
                        "**Cmd+Option+I** — Import Folder",
                        "**Cmd+Shift+S** — Check In Document",
                        "**Cmd+?** — Open Help",
                        "**Cmd+1** — Show All Documents",
                        "**Cmd+2** — Show Templates",
                        "**Cmd+3** — Show Inbox",
                        "**Cmd+4** — Show Flagged",
                        "**Cmd+Option+0** — Show Sidebar"
                    ],
                    tip: nil,
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "iCloud Backup",
                    steps: [
                        "Open **Settings** from the PandyDoc menu.",
                        "Navigate to the **Backup** section.",
                        "Click **Backup to iCloud Drive**.",
                        "Choose a location and confirm."
                    ],
                    tip: "Regular backups protect your document database.",
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "File Watching",
                    steps: [
                        "PandyDoc automatically monitors open documents for changes.",
                        "When you edit a checked-out document externally, PandyDoc detects the change.",
                        "The document status updates automatically when you return to PandyDoc."
                    ],
                    tip: nil,
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "Troubleshooting",
                    steps: [
                        "**Printer not working?** Reinstall via Printer Setup or Terminal.",
                        "**Documents not appearing?** Click the **Refresh** button in the toolbar.",
                        "**Can't check out a document?** Check if it's locked by another user.",
                        "**App not launching?** Try rebuilding from Xcode or reinstalling the DMG."
                    ],
                    tip: "If issues persist, check the Console app for PandyDoc logs.",
                    warning: nil
                )
            }
            .padding()
        }
    }
}
