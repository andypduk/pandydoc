import SwiftUI

struct BackupRestoreTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HelpSectionHeader(
                    title: "Backup & Restore",
                    subtitle: "Protect your documents with Time Machine and built-in backups."
                )

                WalkthroughSection(
                    title: "Time Machine Compatibility",
                    steps: [
                        "PandyDoc stores all data in **~/Library/Application Support/com.pandydoc.vault/**",
                        "This location is **automatically included** in Time Machine backups.",
                        "The backup includes the SQLite database, all documents, and version history.",
                        "No special configuration is needed — Time Machine handles it automatically."
                    ],
                    tip: "Time Machine backs up your data incrementally. You can restore any point in time using macOS Time Machine.",
                    warning: nil
                )

                Divider()

                HelpSectionHeader(title: "Manual Backup", subtitle: "")

                WalkthroughSection(
                    title: "Creating a Backup",
                    steps: [
                        "Open **Settings** from the PandyDoc menu bar.",
                        "Go to the **Backup & Restore** tab.",
                        "Click **Back Up Database...**",
                        "Choose a location on your Mac or iCloud Drive.",
                        "The backup includes the database, documents, and all version history."
                    ],
                    tip: "Store backups on an external drive or iCloud Drive for off-site protection.",
                    warning: nil
                )

                Divider()

                HelpSectionHeader(title: "Restoring from Backup", subtitle: "")

                WalkthroughSection(
                    title: "Restoring a Backup",
                    steps: [
                        "Open **Settings** from the PandyDoc menu bar.",
                        "Go to the **Backup & Restore** tab.",
                        "Click **Restore from Backup...**",
                        "Select a previously created backup folder.",
                        "PandyDoc will replace the current database with the backup.",
                        "The app will restart automatically after restore."
                    ],
                    tip: nil,
                    warning: "Restoring replaces all current data. Make sure you have a backup of your current state before restoring."
                )

                Divider()

                HelpSectionHeader(title: "Backup Contents", subtitle: "")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    BackupContentItem(icon: "database", title: "Database", desc: "pandydoc.sqlite3")
                    BackupContentItem(icon: "doc.text", title: "Documents", desc: "All stored files")
                    BackupContentItem(icon: "clock.arrow.circlepath", title: "Versions", desc: "Version history")
                    BackupContentItem(icon: "lock.shield", title: "Metadata", desc: "Folders, tags, flags")
                }
            }
            .padding()
        }
    }
}

struct BackupContentItem: View {
    let icon: String
    let title: String
    let desc: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body).fontWeight(.medium)
                Text(desc).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
