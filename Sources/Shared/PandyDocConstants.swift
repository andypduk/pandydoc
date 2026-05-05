import Foundation

struct PandyDocConstants {
    static let appGroupIdentifier = "group.com.pandydoc"
    
    static let incomingDocumentsPath = "Incoming"
    static let processedDocumentsPath = "Processed"
    static let documentsPath = "Documents"
    static let versionsPath = "Versions"
    
    static let metadataFileName = "metadata.json"
    
    static let notificationDocumentReceived = "com.pandydoc.documentReceived"
    static let notificationDocumentProcessed = "com.pandydoc.documentProcessed"
    
    static let userDefaultsDocumentKey = "lastProcessedDocument"
    static let userDefaultsPrinterInstalledKey = "printerInstalled"
}

struct PDFPrintJob: Codable {
    let id: UUID
    let fileName: String
    let timestamp: Date
    let filePath: String
    let fileSize: Int64
    let sourceApp: String?
    
    static func create(fileName: String, filePath: String) -> PDFPrintJob {
        let attributes = try? FileManager.default.attributesOfItem(atPath: filePath)
        return PDFPrintJob(
            id: UUID(),
            fileName: fileName,
            timestamp: Date(),
            filePath: filePath,
            fileSize: attributes?[.size] as? Int64 ?? 0,
            sourceApp: Bundle.main.bundleIdentifier
        )
    }
}
