import SwiftUI

struct PrintingTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HelpSectionHeader(
                    title: "Printing to PandyDoc",
                    subtitle: "Capture PDFs from any application using the PandyDoc virtual printer."
                )
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    QuickRefCard(title: "Install Printer", description: "Set up the PandyDoc virtual printer.", icon: "printer.fill") {}
                    QuickRefCard(title: "Print to PandyDoc", description: "Capture PDFs from any app.", icon: "doc.richtext") {}
                    QuickRefCard(title: "View Incoming Documents", description: "See recently printed documents.", icon: "tray.fill") {}
                    QuickRefCard(title: "Troubleshoot Printer", description: "Fix common printer issues.", icon: "wrench") {}
                }
                
                Divider()
                
                HelpSectionHeader(title: "Step-by-Step Guides", subtitle: "")
                
                WalkthroughSection(
                    title: "Install the PandyDoc Printer",
                    steps: [
                        "Click the **Printer Setup** button in the toolbar.",
                        "Follow the installation wizard.",
                        "Enter your administrator password when prompted.",
                        "Once installed, **PandyDoc** appears in your system printers."
                    ],
                    tip: "You can also install via Terminal: sudo ./Scripts/install_printer.sh",
                    warning: "Administrator access is required."
                )
                
                WalkthroughSection(
                    title: "Print a Document to PandyDoc",
                    steps: [
                        "In any application, press Cmd+P to open the Print dialog.",
                        "Select **PandyDoc** from the printer dropdown.",
                        "Click **Print**.",
                        "The PDF is automatically captured and saved to PandyDoc.",
                        "A notification confirms the document was received."
                    ],
                    tip: "You can also use the PDF dropdown in the print dialog and select **Save to PandyDoc**.",
                    warning: nil
                )
                
                WalkthroughSection(
                    title: "View Incoming Documents",
                    steps: [
                        "Click **Inbox** in the sidebar to see recently printed documents.",
                        "The inbox count shows how many unprocessed documents are waiting.",
                        "Documents are automatically imported into PandyDoc."
                    ],
                    tip: nil,
                    warning: nil
                )
            }
            .padding()
        }
    }
}
