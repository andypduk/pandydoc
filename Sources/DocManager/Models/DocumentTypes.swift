import Foundation

enum DocumentStatus: String, Codable {
    case available
    case checkedOut
    case locked
}

enum DocumentType: String, Codable {
    case pdf
    case docx
    case xlsx
    case pptx
    case txt
    case rtf
    case pages
    case numbers
    case key
    case other
    
    static func from(extension ext: String) -> DocumentType {
        switch ext.lowercased() {
        case "pdf": return .pdf
        case "docx", "doc": return .docx
        case "xlsx", "xls", "csv": return .xlsx
        case "pptx", "ppt": return .pptx
        case "txt", "log", "md", "json", "xml", "yaml", "yml", "html", "htm", "css", "js", "swift", "py", "rb", "sh", "bash", "zsh", "ini", "cfg", "config": return .txt
        case "rtf": return .rtf
        case "pages": return .pages
        case "numbers": return .numbers
        case "key", "keynote": return .key
        default: return .other
        }
    }
    
    var mimeType: String {
        switch self {
        case .pdf: return "application/pdf"
        case .docx: return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .xlsx: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case .pptx: return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case .txt: return "text/plain"
        case .rtf: return "application/rtf"
        case .pages: return "application/vnd.apple.pages"
        case .numbers: return "application/vnd.apple.numbers"
        case .key: return "application/vnd.apple.keynote"
        case .other: return "application/octet-stream"
        }
    }
    
    var defaultApp: String? {
        switch self {
        case .pdf: return nil
        case .docx: return "Microsoft Word"
        case .xlsx: return "Microsoft Excel"
        case .pptx: return "Microsoft PowerPoint"
        case .txt, .rtf: return "TextEdit"
        case .pages: return "Pages"
        case .numbers: return "Numbers"
        case .key: return "Keynote"
        case .other: return nil
        }
    }
}
