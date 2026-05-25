import SwiftUI

struct GettingStartedTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HelpSectionHeader(
                    title: "Welcome to PandyDoc",
                    subtitle: "Your macOS document management system with check-in/check-out, versioning, and PDF printing."
                )
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    QuickRefCard(
                        title: "Import Your First Document",
                        description: "Add documents by clicking Import or dragging files into PandyDoc.",
                        icon: "square.and.arrow.down"
                    ) {}
                    
                    QuickRefCard(
                        title: "Set Up the Printer",
                        description: "Install the PandyDoc printer to capture PDFs from any app.",
                        icon: "printer"
                    ) {}
                    
                    QuickRefCard(
                        title: "Check Out & Edit",
                        description: "Open documents for editing with automatic version tracking.",
                        icon: "pencil"
                    ) {}
                    
                    QuickRefCard(
                        title: "Create a Folder",
                        description: "Organize documents into folders for easy navigation.",
                        icon: "folder.badge.plus"
                    ) {}
                }
                
                Divider()
                
                HelpSectionHeader(title: "Step-by-Step Guides", subtitle: "")
                
                WalkthroughSection(
                    title: "Import Your First Document",
                    steps: [
                        "Click the **Import** button in the toolbar, or press Cmd+I.",
                        "Select one or more files from the file picker.",
                        "Click **Open** to import them into PandyDoc.",
                        "Your documents appear in the **All Documents** section of the sidebar."
                    ],
                    tip: "You can also drag and drop files directly onto the PandyDoc window.",
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "Set Up the PandyDoc Printer",
                    steps: [
                        "Click the **Printer Setup** button in the toolbar.",
                        "Click **Install** to add the PDF service.",
                        "Once installed, you'll see **Save PDF to PandyDoc** in the PDF menu of any app's print dialog.",
                        "Select it to capture and save the PDF directly to your PandyDoc library."
                    ],
                    tip: "Click **Remove** in Printer Setup to uninstall the PDF service.",
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "Check Out & Edit a Document",
                    steps: [
                        "Select a document in the sidebar or document list.",
                        "Click **Check Out & Edit** or right-click and select **Check Out**.",
                        "The document opens in its default application.",
                        "Make your changes and save them.",
                        "Return to PandyDoc and click **Check In** to save a new version."
                    ],
                    tip: "Changes are automatically tracked — each check-in creates a new version with a timestamp.",
                    warning: "Only one person can check out a document at a time."
                )
            }
            .padding()
        }
    }
}
