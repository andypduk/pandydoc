import SwiftUI

struct PrinterSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var installOutput = ""
    @State private var isInstalling = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("PandyDoc Printer Setup") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Install PandyDoc as a system printer to capture PDFs from any application.")
                            .font(.body)
                        
                        LabeledContent("Printer Name", value: "PandyDoc PDF")
                        LabeledContent("Type", value: "Virtual PDF Printer")
                        LabeledContent("Location", value: "Local")
                    }
                }
                
                Section("Installation Steps") {
                    VStack(alignment: .leading, spacing: 8) {
                        StepView(number: 1, text: "Click Install to setup the CUPS printer backend")
                        StepView(number: 2, text: "Open any application and select Print (Cmd+P)")
                        StepView(number: 3, text: "Select 'PandyDoc PDF' from the printer list")
                        StepView(number: 4, text: "The PDF will be saved to PandyDoc automatically")
                    }
                }
                
                Section("Manual Installation") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You can also install manually via Terminal:")
                            .font(.caption)
                        
                        ScrollView(.horizontal) {
                            Text(manualInstallCommand)
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        Button("Copy Command") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(manualInstallCommand, forType: .string)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Printer Setup")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { installPrinter() }) {
                        if isInstalling {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Installing...")
                        } else {
                            Label("Install Printer", systemImage: "printer")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isInstalling)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 450, height: 400)
    }
    
    private var manualInstallCommand: String {
        """
        sudo lpadmin -p PandyDoc -E -v pandydoc://localhost \
          -P /Library/Printers/PPDs/Contents/Resources/PandyDoc.ppd
        """
    }
    
    private func installPrinter() {
        isInstalling = true
        
        let script = PDFPrinterService.shared.setupCUPSPrinter()
        
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", """
        echo "Creating directories..."
        mkdir -p ~/Library/Application\\ Support/PandyDoc/Incoming
        mkdir -p ~/Library/Application\\ Support/PandyDoc/Processed
        echo "Done. Please run the following command in Terminal with sudo:"
        echo ""
        echo "\(manualInstallCommand)"
        echo ""
        echo "Note: Full installation requires admin privileges."
        """
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            installOutput = String(data: data, encoding: .utf8) ?? ""
        } catch {
            installOutput = "Error: \(error.localizedDescription)"
        }
        
        isInstalling = false
    }
}

struct StepView: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 24, height: 24)
                .overlay(
                    Text("\(number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
