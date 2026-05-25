import SwiftUI

enum DesignTokens {
    enum Colors {
        static let statusAvailable = Color(red: 0.20, green: 0.78, blue: 0.35)
        static let statusCheckedOut = Color(red: 0.00, green: 0.48, blue: 1.00)
        static let statusLocked = Color(red: 1.00, green: 0.23, blue: 0.19)
        static let selectionBackground = Color.accentColor.opacity(0.08)
        static let separatorThin = Color.black.opacity(0.08)
        static let cardBackground = Color(NSColor.controlBackgroundColor)
        static let tagChipBackground = Color.accentColor.opacity(0.1)
        static let badgeBackground = Color.accentColor.opacity(0.2)
        static let sidebarCardBackground = Color(NSColor.controlBackgroundColor)
        static let statsBarBackground = Color(NSColor.controlBackgroundColor)
    }
    
    enum FileTypeColor {
        static func gradient(for type: DocumentType) -> [Color] {
            switch type {
            case .pdf: return [Color(red: 1.00, green: 0.23, blue: 0.19), Color(red: 1.00, green: 0.58, blue: 0.00)]
            case .docx, .pages: return [Color(red: 0.35, green: 0.34, blue: 0.84), Color(red: 0.69, green: 0.32, blue: 0.87)]
            case .xlsx, .numbers: return [Color(red: 0.00, green: 0.48, blue: 1.00), Color(red: 0.35, green: 0.34, blue: 0.84)]
            case .pptx, .key: return [Color(red: 1.00, green: 0.58, blue: 0.00), Color(red: 1.00, green: 0.80, blue: 0.00)]
            case .txt, .rtf: return [Color(red: 0.56, green: 0.56, blue: 0.58), Color(red: 0.39, green: 0.39, blue: 0.40)]
            case .other: return [Color(red: 0.56, green: 0.56, blue: 0.58), Color(red: 0.39, green: 0.39, blue: 0.40)]
            }
        }
        
        static func icon(for type: DocumentType) -> String {
            switch type {
            case .pdf: return "doc.richtext"
            case .docx, .pages: return "doc.text"
            case .xlsx, .numbers: return "tablecells"
            case .pptx, .key: return "play.rectangle.fill"
            case .txt: return "doc.plaintext"
            case .rtf: return "doc.richtext"
            case .other: return "doc"
            }
        }
        
        static func label(for type: DocumentType) -> String {
            switch type {
            case .pdf: return "PDF"
            case .docx, .pages: return "DOC"
            case .xlsx, .numbers: return "XLS"
            case .pptx, .key: return "PPT"
            case .txt, .rtf: return "TXT"
            case .other: return "FILE"
            }
        }
    }
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }
    
    enum Corner {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
        static let xxl: CGFloat = 16
    }
    
    enum Typography {
        static func titleStyle() -> Font {
            Font.title3.weight(.semibold)
        }
        static func bodyStyle() -> Font {
            Font.body.weight(.regular)
        }
        static func metadataStyle() -> Font {
            Font.caption.weight(.medium)
        }
        static func labelStyle() -> Font {
            Font.caption2.weight(.semibold)
        }
        static func statsNumberStyle() -> Font {
            Font.system(size: 16, weight: .bold, design: .rounded)
        }
        static func statsLabelStyle() -> Font {
            Font.system(size: 10, weight: .medium, design: .rounded)
        }
    }
}
