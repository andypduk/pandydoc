import Foundation
import AppKit
import QuickLookThumbnailing
import PDFKit

final class PDFPreviewGenerator {
    static let shared = PDFPreviewGenerator()
    
    private let cacheDir: URL
    
    private init() {
        cacheDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PandyDoc/Previews", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        print("PDFPreviewGenerator: Cache dir at \(cacheDir.path)")
    }
    
    func cachedPDFURL(for documentID: UUID) -> URL {
        cacheDir.appendingPathComponent("\(documentID.uuidString)_preview.pdf")
    }
    
    func hasCachedPDF(for documentID: UUID) -> Bool {
        let url = cachedPDFURL(for: documentID)
        let exists = FileManager.default.fileExists(atPath: url.path)
        print("PDFPreviewGenerator: hasCachedPDF(\(documentID)) -> \(exists)")
        return exists
    }
    
    func clearCachedPDF(for documentID: UUID) {
        try? FileManager.default.removeItem(at: cachedPDFURL(for: documentID))
    }
    
    func generatePDF(from sourceURL: URL, documentID: UUID) async -> Bool {
        print("PDFPreviewGenerator: generatePDF from \(sourceURL.path)")
        let outputURL = cachedPDFURL(for: documentID)
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        let ext = sourceURL.pathExtension.lowercased()
        print("PDFPreviewGenerator: File extension = \(ext)")
        
        if ext == "docx" || ext == "doc" {
            print("PDFPreviewGenerator: Converting Word document")
            return await convertWordToPDF(from: sourceURL, to: outputURL)
        } else if ext == "pptx" || ext == "ppt" {
            print("PDFPreviewGenerator: Converting PowerPoint document")
            return await convertViaQuickLook(from: sourceURL, to: outputURL)
        }
        
        print("PDFPreviewGenerator: Unsupported extension")
        return false
    }
    
    private func convertWordToPDF(from sourceURL: URL, to outputURL: URL) async -> Bool {
        let rtfURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PandyDoc/Previews/\(UUID().uuidString).rtf")
        
        do {
            try FileManager.default.createDirectory(at: rtfURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            
            print("PDFPreviewGenerator: Running textutil to convert docx -> rtf")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
            process.arguments = ["-convert", "rtf", "-output", rtfURL.path, sourceURL.path]
            
            try process.run()
            process.waitUntilExit()
            
            print("PDFPreviewGenerator: textutil exit code = \(process.terminationStatus)")
            
            guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: rtfURL.path) else {
                print("PDFPreviewGenerator: textutil failed or RTF not created")
                return false
            }
            
            let rtfSize = try? FileManager.default.attributesOfItem(atPath: rtfURL.path)[.size] as? Int64
            print("PDFPreviewGenerator: RTF file created, size = \(rtfSize ?? 0) bytes")
            
            let success = await printRTFToPDF(from: rtfURL, to: outputURL)
            print("PDFPreviewGenerator: RTF -> PDF conversion result = \(success)")
            
            try? FileManager.default.removeItem(at: rtfURL)
            return success
        } catch {
            print("PDFPreviewGenerator: textutil error: \(error)")
            return false
        }
    }
    
    private func convertViaQuickLook(from sourceURL: URL, to outputURL: URL) async -> Bool {
        print("PDFPreviewGenerator: Using qlmanage to generate preview for \(sourceURL.lastPathComponent)")
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PandyDoc/Previews")
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
            process.arguments = ["-t", "-s", "3000", "-o", tempDir.path, sourceURL.path]
            
            let pipe = Pipe()
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            if let errorStr = String(data: errorData, encoding: .utf8) {
                print("PDFPreviewGenerator: qlmanage stderr: \(errorStr)")
            }
            
            print("PDFPreviewGenerator: qlmanage exit code = \(process.terminationStatus)")
            
            if process.terminationStatus == 0 {
                let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                let pngFiles = contents.filter { $0.pathExtension == "png" }
                print("PDFPreviewGenerator: Found PNG files: \(pngFiles.map { $0.lastPathComponent })")
                
                if let pngURL = pngFiles.first {
                    if let image = NSImage(contentsOf: pngURL) {
                        let pdfDoc = PDFDocument()
                        let pdfPage = PDFPage(image: image)
                        if let page = pdfPage {
                            pdfDoc.insert(page, at: 0)
                            pdfDoc.write(to: outputURL)
                            print("PDFPreviewGenerator: PDF created from qlmanage thumbnail")
                            try? FileManager.default.removeItem(at: pngURL)
                            return true
                        }
                    }
                    try? FileManager.default.removeItem(at: pngURL)
                }
            }
        } catch {
            print("PDFPreviewGenerator: qlmanage error: \(error)")
        }
        
        print("PDFPreviewGenerator: QuickLook conversion failed")
        return false
    }
    
    private func printRTFToPDF(from rtfURL: URL, to outputURL: URL) async -> Bool {
        print("PDFPreviewGenerator: Converting RTF to PDF via NSPrintOperation")
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let rtfData = try? Data(contentsOf: rtfURL),
                      let attrString = NSAttributedString(rtf: rtfData, documentAttributes: nil) else {
                    print("PDFPreviewGenerator: Failed to load RTF data")
                    continuation.resume(returning: false)
                    return
                }
                
                print("PDFPreviewGenerator: RTF loaded, length = \(attrString.length)")
                
                let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
                textView.textStorage?.setAttributedString(attrString)
                
                let printInfoDict: [NSPrintInfo.AttributeKey: Any] = [
                    .jobDisposition: NSPrintInfo.JobDisposition.save,
                    .jobSavingURL: outputURL
                ]
                let printInfo = NSPrintInfo(dictionary: printInfoDict)
                
                let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
                printOperation.showsPrintPanel = false
                printOperation.showsProgressPanel = false
                
                print("PDFPreviewGenerator: Running print operation...")
                let success = printOperation.run()
                print("PDFPreviewGenerator: Print operation result = \(success)")
                
                if success {
                    let pdfExists = FileManager.default.fileExists(atPath: outputURL.path)
                    print("PDFPreviewGenerator: PDF file exists after print = \(pdfExists)")
                    if pdfExists {
                        let pdfSize = try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64
                        print("PDFPreviewGenerator: PDF file size = \(pdfSize ?? 0) bytes")
                    }
                }
                
                continuation.resume(returning: success)
            }
        }
    }
    
    func shouldGeneratePreview(for filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        return ext == "docx" || ext == "pptx" || ext == "doc" || ext == "ppt"
    }
}
