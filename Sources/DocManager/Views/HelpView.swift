import SwiftUI

enum HelpTab: Int, CaseIterable, Identifiable {
    case gettingStarted = 0
    case managingDocuments = 1
    case organizing = 2
    case templatesVersions = 3
    case printing = 4
    case advanced = 5
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .gettingStarted: return "Getting Started"
        case .managingDocuments: return "Managing Documents"
        case .organizing: return "Organizing"
        case .templatesVersions: return "Templates & Versions"
        case .printing: return "Printing"
        case .advanced: return "Advanced"
        }
    }
    
    var icon: String {
        switch self {
        case .gettingStarted: return "sparkles"
        case .managingDocuments: return "doc.text"
        case .organizing: return "folder"
        case .templatesVersions: return "doc.on.doc"
        case .printing: return "printer"
        case .advanced: return "gearshape"
        }
    }
}

struct HelpView: View {
    @State private var selectedTab: HelpTab = .gettingStarted
    var initialTab: HelpTab?
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                GettingStartedTab().tag(HelpTab.gettingStarted)
                ManagingDocumentsTab().tag(HelpTab.managingDocuments)
                OrganizingTab().tag(HelpTab.organizing)
                TemplatesVersionsTab().tag(HelpTab.templatesVersions)
                PrintingTab().tag(HelpTab.printing)
                AdvancedTab().tag(HelpTab.advanced)
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .frame(width: 700, height: 500)
        .onAppear {
            if let initial = initialTab {
                selectedTab = initial
            }
        }
    }
}
