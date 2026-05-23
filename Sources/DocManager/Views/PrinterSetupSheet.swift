import SwiftUI

struct PrinterSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isInstallingService = false
    @State private var isInstallingPrinter = false
    @State private var serviceInstalled = false
    @State private var printerInstalled = false
    @State private var statusMessage: String?
    @State private var showStatus = false

    private let printerService = PDFPrinterService.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Save to PandyDoc") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            Text("PDF Print Service")
                                .font(.headline)
                        }

                        Text("Adds 'Save to PandyDoc' to the PDF menu in any print dialog. No admin privileges required.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Image(systemName: serviceInstalled ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(serviceInstalled ? .green : .secondary)
                            Text(serviceInstalled ? "Installed" : "Not installed")
                                .font(.caption)
                                .foregroundColor(serviceInstalled ? .green : .secondary)
                            Spacer()
                            Button(action: installPDFService) {
                                if isInstallingService {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Label(serviceInstalled ? "Reinstall" : "Install", systemImage: "arrow.down.circle")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isInstallingService)
                        }
                    }
                }

                Section("System Printer") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "printer")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            Text("PandyDoc PDF Printer")
                                .font(.headline)
                        }

                        Text("Installs a virtual printer. Requires admin privileges and Terminal commands.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Image(systemName: printerInstalled ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(printerInstalled ? .green : .secondary)
                            Text(printerInstalled ? "Installed" : "Not installed")
                                .font(.caption)
                                .foregroundColor(printerInstalled ? .green : .secondary)
                            Spacer()
                            Button(action: installSystemPrinter) {
                                if isInstallingPrinter {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Label("Setup", systemImage: "terminal")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isInstallingPrinter)
                        }
                    }
                }

                Section("How It Works") {
                    VStack(alignment: .leading, spacing: 8) {
                        HowItWorksStep(number: 1, text: "Open any application and press Cmd+P to print")
                        HowItWorksStep(number: 2, text: "Click the PDF dropdown in the print dialog")
                        HowItWorksStep(number: 3, text: "Select 'Save to PandyDoc' from the menu")
                        HowItWorksStep(number: 4, text: "The PDF is saved directly to your PandyDoc library")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Printer Setup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 450, height: 480)
        .onAppear {
            checkInstallStatus()
        }
        .alert(statusMessage ?? "", isPresented: $showStatus) {
            Button("OK", role: .cancel) {}
        }
    }

    private func checkInstallStatus() {
        serviceInstalled = printerService.isPDFServiceInstalled()
        printerInstalled = checkPrinterInstalled()
    }

    private func checkPrinterInstalled() -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/lpstat"
        process.arguments = ["-p", "PandyDoc"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private func installPDFService() {
        isInstallingService = true
        let success = printerService.installPDFService()
        isInstallingService = false
        serviceInstalled = success
        statusMessage = success ? "PDF Service installed successfully. 'Save to PandyDoc' is now available in print dialogs." : "Failed to install PDF Service"
        showStatus = true
    }

    private func installSystemPrinter() {
        let command = printerService.setupCUPSPrinter()
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("install_pandydoc_printer.sh")

        do {
            try command.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            NSWorkspace.shared.open(scriptURL)

            statusMessage = "Terminal will open with the install script. Enter your password when prompted."
            showStatus = true
        } catch {
            statusMessage = "Failed to create install script: \(error.localizedDescription)"
            showStatus = true
        }
    }
}

struct HowItWorksStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 24, height: 24)
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
