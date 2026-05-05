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
        case "xlsx", "xls": return .xlsx
        case "txt": return .txt
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
        case .txt, .rtf: return "TextEdit"
        case .pages: return "Pages"
        case .numbers: return "Numbers"
        case .key: return "Keynote"
        case .other: return nil
        }
    }
}
