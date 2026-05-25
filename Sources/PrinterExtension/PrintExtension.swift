import Cocoa
import Quartz

@MainActor
class PrintExtension: NSViewController, NSPrintPanelAccessorizing {
    
    @IBOutlet weak var documentNameField: NSTextField!
    @IBOutlet weak var tagsField: NSTextField!
    @IBOutlet weak var notesView: NSTextView!
    
    override var nibName: NSNib.Name? {
        return NSNib.Name("PrintExtension")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    func localizedString(forKey key: String) -> String {
        switch key {
        case "summaryTitle":
            return "PandyDoc"
        case "summaryLabel":
            return "Save PDF to PandyDoc"
        default:
            return ""
        }
    }
    
    func accessoryViews() -> [NSView] {
        return [self.view]
    }
    
    func layoutSummaryView() {
    }
    
    func localizedSummaryItems() -> [[NSPrintPanel.AccessorySummaryKey : String]] {
        return []
    }
    
    private func setupUI() {
        documentNameField.placeholderString = "Document name"
        tagsField.placeholderString = "Tags (comma separated)"
    }
    
    func getPrintSettings() -> [String: Any] {
        return [
            "pandydoc_documentName": documentNameField.stringValue,
            "pandydoc_tags": tagsField.stringValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            "pandydoc_notes": notesView?.string ?? ""
        ]
    }
}
