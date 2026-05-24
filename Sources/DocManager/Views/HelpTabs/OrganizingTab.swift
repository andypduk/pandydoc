import SwiftUI

struct OrganizingTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HelpSectionHeader(
                    title: "Organizing Documents",
                    subtitle: "Use folders, tags, and search to keep your documents organized."
                )
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    QuickRefCard(title: "Create a Folder", description: "Group documents into folders.", icon: "folder.badge.plus") {}
                    QuickRefCard(title: "Add Tags", description: "Tag documents for easy filtering.", icon: "tag") {}
                    QuickRefCard(title: "Search Documents", description: "Find documents by name or content.", icon: "magnifyingglass") {}
                    QuickRefCard(title: "Flag Documents", description: "Mark important documents for quick access.", icon: "flag.fill") {}
                }
                
                Divider()
                
                HelpSectionHeader(title: "Step-by-Step Guides", subtitle: "")
                
                WalkthroughSection(
                    title: "Create and Manage Folders",
                    steps: [
                        "Click the **+** button next to **Folders** in the sidebar.",
                        "Enter a name for the folder and press Enter.",
                        "Drag documents into the folder to organize them.",
                        "Right-click a folder to **Rename**, **Archive**, or **Delete** it."
                    ],
                    tip: "You can create subfolders by right-clicking a folder and selecting **New Subfolder**.",
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "Add and Filter by Tags",
                    steps: [
                        "Select a document and look at the **Tags** section in the detail panel.",
                        "Type a tag name in the **Add tag...** field and press Enter.",
                        "Click a tag in the sidebar to filter documents by that tag.",
                        "Click **Clear filters** to remove tag filtering."
                    ],
                    tip: "Tags are case-insensitive and automatically capitalized.",
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "Search for Documents",
                    steps: [
                        "Click the **Search** field at the top of the document list.",
                        "Type a search term — results filter in real-time.",
                        "Press Enter to search, or click the **X** to clear."
                    ],
                    tip: "Search matches document names and tags.",
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "Flag Important Documents",
                    steps: [
                        "Right-click a document and select **Flag**.",
                        "Flagged documents appear in the **Flagged** section of the sidebar.",
                        "Click **Flagged** in the sidebar to view all flagged documents.",
                        "Right-click a flagged document and select **Unflag** to remove the flag."
                    ],
                    tip: nil,
                    warning: nil
                )
            }
            .padding()
        }
    }
}
