import SwiftUI

struct TemplatesVersionsTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HelpSectionHeader(
                    title: "Templates & Versions",
                    subtitle: "Create reusable templates and track document history."
                )
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    QuickRefCard(title: "Create a Template", description: "Save a document as a reusable template.", icon: "doc.badge.plus") {}
                    QuickRefCard(title: "New from Template", description: "Create a new document based on a template.", icon: "doc.on.doc") {}
                    QuickRefCard(title: "View Version History", description: "See all versions of a document.", icon: "clock.arrow.circlepath") {}
                    QuickRefCard(title: "Restore a Version", description: "Revert to a previous version.", icon: "arrow.uturn.backward") {}
                }
                
                Divider()
                
                HelpSectionHeader(title: "Step-by-Step Guides", subtitle: "")
                
                WalkthroughSection(
                    title: "Create a Template",
                    steps: [
                        "Right-click a document and select **Add to Templates**.",
                        "The document appears in the **Templates** section of the sidebar.",
                        "Templates are locked by default — they cannot be edited or deleted directly.",
                        "To use a template, right-click it and select **New from Template**."
                    ],
                    tip: "Templates are perfect for standard forms, contracts, or recurring document types.",
                    warning: "⚠️ Locked templates cannot be opened, edited, exported, or deleted."
                )
                
                WalkthroughSection(
                    title: "Create a New Document from a Template",
                    steps: [
                        "Navigate to the **Templates** section in the sidebar.",
                        "Right-click the template you want to use.",
                        "Select **New from Template**.",
                        "A copy of the template is created in **All Documents**."
                    ],
                    tip: nil,
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "View Version History",
                    steps: [
                        "Select a document in the list.",
                        "Right-click and select **Version History**, or click the **Versions** button.",
                        "A window shows all versions with timestamps, authors, and change notes.",
                        "Click **Restore** on any version to revert to that version."
                    ],
                    tip: "Each check-in automatically creates a new version.",
                    warning: "⚠️ Restoring a version creates a new version — it does not delete existing versions."
                )
            }
            .padding()
        }
    }
}
