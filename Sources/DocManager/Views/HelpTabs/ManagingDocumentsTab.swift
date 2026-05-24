import SwiftUI

struct ManagingDocumentsTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HelpSectionHeader(
                    title: "Managing Documents",
                    subtitle: "Import, edit, lock, export, and manage your documents."
                )
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    QuickRefCard(title: "Open a Document", description: "Open documents in their default application for viewing.", icon: "arrow.up.right.square") {}
                    QuickRefCard(title: "Lock a Document", description: "Prevent others from editing a document.", icon: "lock.fill") {}
                    QuickRefCard(title: "Export a Document", description: "Save a copy of a document outside PandyDoc.", icon: "square.and.arrow.up") {}
                    QuickRefCard(title: "Delete a Document", description: "Remove a document permanently.", icon: "trash.fill") {}
                }
                
                Divider()
                
                HelpSectionHeader(title: "Step-by-Step Guides", subtitle: "")
                
                WalkthroughSection(
                    title: "Open a Document",
                    steps: [
                        "Select a document in the list.",
                        "Right-click and select **Open**, or click the **Open** button in the toolbar.",
                        "The document opens in its default application."
                    ],
                    tip: "Locked documents can be viewed but not opened for editing.",
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "Lock and Unlock Documents",
                    steps: [
                        "Select a document and right-click.",
                        "Choose **Lock** to prevent others from editing it.",
                        "To unlock, right-click the locked document and select **Unlock**.",
                        "Only the person who locked the document can unlock it."
                    ],
                    tip: nil,
                    warning: "⚠️ Locked documents cannot be opened or edited by other users."
                )
                
                WalkthroughSection(
                    title: "Export a Document",
                    steps: [
                        "Right-click the document you want to export.",
                        "Select **Export...** from the context menu.",
                        "Choose a location and filename in the save panel.",
                        "Click **Save** to export a copy."
                    ],
                    tip: nil,
                    warning: "Template documents that are locked cannot be exported. Create a new document from the template instead."
                )
                
                WalkthroughSection(
                    title: "Delete a Document",
                    steps: [
                        "Right-click the document you want to delete.",
                        "Select **Delete** from the context menu.",
                        "Confirm the deletion in the alert."
                    ],
                    tip: nil,
                    warning: "⚠️ Deleted documents cannot be recovered. Make sure you have a backup if needed."
                )
            }
            .padding()
        }
    }
}
