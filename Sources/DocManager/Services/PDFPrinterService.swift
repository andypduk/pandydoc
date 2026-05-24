import Foundation

final class PDFPrinterService {
    static let shared = PDFPrinterService()
    
    private let storage: DocumentStorageProtocol
    private let fileManager = FileManager.default
    private var incomingDir: URL
    
    private init(storage: DocumentStorageProtocol = DocumentStorage.shared) {
        self.storage = storage
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not locate Application Support directory")
        }
        let pandyDocSupport = appSupport.appendingPathComponent("PandyDoc", isDirectory: true)
        
        var canUseAppSupport = false
        do {
            try? FileManager.default.createDirectory(at: pandyDocSupport, withIntermediateDirectories: true)
            let testFile = pandyDocSupport.appendingPathComponent(".write_test")
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(at: testFile)
            canUseAppSupport = true
        } catch {
            print("PDFPrinterService: AppSupport not writable, using fallback")
        }
        
        let baseDir = canUseAppSupport ? pandyDocSupport : homeDir.appendingPathComponent("Documents/PandyDoc", isDirectory: true)
        incomingDir = baseDir.appendingPathComponent("Incoming", isDirectory: true)
        try? FileManager.default.createDirectory(at: incomingDir, withIntermediateDirectories: true)
    }
    
    func initialize() throws {
        if !fileManager.fileExists(atPath: incomingDir.path) {
            try fileManager.createDirectory(at: incomingDir, withIntermediateDirectories: true)
        }
    }
    
    func processPrintedPDF(from sourceURL: URL, jobName: String) throws -> Document {
        let fileName = sanitizeFileName(jobName.hasSuffix(".pdf") ? jobName : "\(jobName).pdf")
        let destURL = incomingDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        
        try fileManager.copyItem(at: sourceURL, to: destURL)
        
        let document = try storage.storeReceivedPDF(
            sourcePath: destURL.path,
            fileName: fileName,
            parentID: nil
        )
        
        try? fileManager.removeItem(at: destURL)
        
        NotificationCenter.default.post(
            name: .documentReceived,
            object: nil,
            userInfo: ["documentId": document.id, "documentName": document.name]
        )
        
        return document
    }
    
    func installPrinter() {
        let script = """
        #!/bin/bash
        
        CUPS_BACKEND="/Library/Printers/PandyDoc"
        mkdir -p "$CUPS_BACKEND"
        
        cat > "$CUPS_BACKEND/pandydoc" << 'SCRIPT'
        #!/bin/bash
        
        # CUPS backend for PandyDoc
        # Receives PDF and saves to PandyDoc document management system
        
        JOBTITLE="$6"
        OUTPUT_FILE="$HOME/Library/Application Support/PandyDoc/Incoming/${JOBTITLE// /_}_$(date +%s).pdf"
        
        mkdir -p "$(dirname "$OUTPUT_FILE")"
        
        if [ -f "$7" ]; then
            cp "$7" "$OUTPUT_FILE"
        else
            cat > "$OUTPUT_FILE"
        fi
        
        echo "INFO: PDF saved to $OUTPUT_FILE"
        exit 0
        SCRIPT
        
        chmod +x "$CUPS_BACKEND/pandydoc"
        chown root:wheel "$CUPS_BACKEND/pandydoc"
        """
        print("Printer installation script:\n\(script)")
    }
    
    func setupCUPSPrinter() -> String {
        """
        #!/bin/bash
        # Install PandyDoc as a CUPS printer
        # Run with: sudo ./install_printer.sh
        
        PRINTER_NAME="PandyDoc"
        PPD_FILE="/Library/Printers/PPDs/Contents/Resources/PandyDoc.ppd"
        BACKEND_PATH="/Library/Printers/PandyDoc/pandydoc"
        
        mkdir -p /Library/Printers/PandyDoc
        mkdir -p "$HOME/Library/Application Support/PandyDoc/Incoming"
        mkdir -p "$HOME/Library/Application Support/PandyDoc/Processed"
        
        cat > "$BACKEND_PATH" << 'EOF'
        #!/bin/bash
        # CUPS Backend for PandyDoc
        # Parameters: job-id user title copies options [file]
        
        JOBTITLE="${3:-PandyDoc_Print}"
        TIMESTAMP=$(date +%s)
        OUTPUT_DIR="$HOME/Library/Application Support/PandyDoc/Incoming"
        OUTPUT_FILE="$OUTPUT_DIR/${JOBTITLE// /_}_${TIMESTAMP}.pdf"
        
        mkdir -p "$OUTPUT_DIR"
        
        if [ "$#" -ge 7 ] && [ -f "$7" ]; then
            cp "$7" "$OUTPUT_FILE"
        else
            cat > "$OUTPUT_FILE"
        fi
        
        echo "PDF received: $OUTPUT_FILE"
        exit 0
        EOF
        
        chmod 0755 "$BACKEND_PATH"
        chown root:_lp "$BACKEND_PATH"
        
        # Create PPD file
        cat > "$PPD_FILE" << 'PPDEOF'
        *PPD-Adobe: "4.3"
        *FormatVersion: "4.3"
        *FileVersion: "1.0"
        *LanguageVersion: English
        *LanguageEncoding: ISOLatin1
        *PCFileName: "pandydoc.ppd"
        *Product: "(PandyDoc)"
        *Manufacturer: "PandyDoc"
        *ModelName: "PandyDoc PDF"
        *ShortNickName: "PandyDoc"
        *NickName: "PandyDoc Document Manager"
        *PSVersion: "(3010) 0"
        *PSVersion: "(3010) 0"
        *LanguageLevel: "3"
        *ColorDevice: True
        *DefaultColorSpace: RGB
        *Throughput: "1"
        *TTRasterizer: Type42
        *cupsFilter: "application/pdf 0 pandydoc"
        *cupsFilter: "application/postscript 0 pandydoc"
        *OpenUI *PageSize/Media Size: PickOne
        *OrderDependency: 10 AnySetup *PageSize
        *DefaultPageSize: Letter
        *PageSize Letter/US Letter: "<</PageSize[612 792]/ImagingBBox null>>setpagedevice"
        *PageSize A4/A4: "<</PageSize[595 842]/ImagingBBox null>>setpagedevice"
        *PageSize Legal/Legal: "<</PageSize[612 1008]/ImagingBBox null>>setpagedevice"
        *CloseUI: *PageSize
        *OpenUI *PageRegion: PickOne
        *OrderDependency: 10 AnySetup *PageRegion
        *DefaultPageRegion: Letter
        *PageRegion Letter/US Letter: "<</PageSize[612 792]/ImagingBBox null>>setpagedevice"
        *PageRegion A4/A4: "<</PageSize[595 842]/ImagingBBox null>>setpagedevice"
        *CloseUI: *PageRegion
        *DefaultImageableArea: Letter
        *ImageableArea Letter/US Letter: "18 36 594 756"
        *ImageableArea A4/A4: "18 36 577 806"
        *DefaultPaperDimension: Letter
        *PaperDimension Letter/US Letter: "612 792"
        *PaperDimension A4/A4: "595 842"
        *Font Helvetica: Standard "(001.006S)" Standard ROM
        *Font Helvetica-Bold: Standard "(001.007S)" Standard ROM
        *Font Helvetica-Oblique: Standard "(001.006S)" Standard ROM
        *Font Helvetica-BoldOblique: Standard "(001.007S)" Standard ROM
        *Font Courier: Standard "(002.004S)" Standard ROM
        *Font Courier-Bold: Standard "(002.004S)" Standard ROM
        *Font Courier-Oblique: Standard "(002.004S)" Standard ROM
        *Font Courier-BoldOblique: Standard "(002.004S)" Standard ROM
        *Font Times-Roman: Standard "(001.004S)" Standard ROM
        *Font Times-Bold: Standard "(001.007S)" Standard ROM
        *Font Times-Italic: Standard "(001.006S)" Standard ROM
        *Font Times-BoldItalic: Standard "(001.007S)" Standard ROM
        *Font Symbol: Special "(001.004S)" Special ROM
        *Font ZapfDingbats: Special "(001.004S)" Special ROM
        PPDEOF
        
        # Add printer to CUPS
        lpadmin -p "$PRINTER_NAME" -E -v pandydoc://localhost -P "$PPD_FILE"
        cupsenable "$PRINTER_NAME"
        cupsaccept "$PRINTER_NAME"
        
        echo "PandyDoc printer installed successfully!"
        echo "You can now print to 'PandyDoc' from any application."
        """
    }
    
    private func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?*<|:\"'")
        var sanitized = name.components(separatedBy: invalidChars).joined()
        if sanitized.isEmpty {
            sanitized = "Document"
        }
        return sanitized
    }

    func installPDFService() -> Bool {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let pdfServicesDir = homeDir.appendingPathComponent("Library/PDF Services", isDirectory: true)
        let incomingPath = homeDir.appendingPathComponent("Library/Application Support/PandyDoc/Incoming").path

        do {
            try fileManager.createDirectory(at: pdfServicesDir, withIntermediateDirectories: true)

            let appBundleURL = pdfServicesDir.appendingPathComponent("Save to PandyDoc.app")

            if fileManager.fileExists(atPath: appBundleURL.path) {
                try fileManager.removeItem(at: appBundleURL)
            }

            let appleScript = """
            on open these_items
                set incoming_dir to "\(incomingPath)"
                do shell script "mkdir -p " & quoted form of incoming_dir
                repeat with this_item in these_items
                    set item_path to POSIX path of this_item
                    set item_name to do shell script "basename " & quoted form of item_path
                    set uuid to do shell script "uuidgen"
                    set dest_path to incoming_dir & "/" & uuid & "-" & item_name
                    do shell script "cp " & quoted form of item_path & " " & quoted form of dest_path
                end repeat
            end open
            """

            let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("SaveToPandyDoc.applescript")
            try appleScript.write(to: scriptURL, atomically: true, encoding: .utf8)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osacompile")
            process.arguments = ["-o", appBundleURL.path, scriptURL.path]
            try process.run()
            process.waitUntilExit()

            try? fileManager.removeItem(at: scriptURL)

            guard process.terminationStatus == 0, fileManager.fileExists(atPath: appBundleURL.path) else {
                print("PDFPrinterService: osacompile failed with exit code \(process.terminationStatus)")
                return false
            }

            let plistURL = appBundleURL.appendingPathComponent("Contents/Info.plist")
            if let plistData = try? Data(contentsOf: plistURL),
               var plistDict = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                plistDict["LSUIElement"] = true
                let newData = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
                try newData.write(to: plistURL)
            }

            print("PDFPrinterService: installed to \(appBundleURL.path)")
            return true
        } catch {
            print("PDFPrinterService: Failed to install PDF Service: \(error)")
            return false
        }
    }

    func isPDFServiceInstalled() -> Bool {
        let pdfServicesDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/PDF Services", isDirectory: true)
        let appBundleURL = pdfServicesDir.appendingPathComponent("Save to PandyDoc.app")
        return FileManager.default.fileExists(atPath: appBundleURL.path)
    }
}
