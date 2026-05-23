import SwiftUI

struct PrinterSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isInstallingService = false
    @State private var serviceInstalled = false
    @State private var statusMessage: String?
    @State private var showStatus = false

    private let printerService = PDFPrinterService.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
        .frame(width: 450, height: 300)
        .onAppear {
            checkInstallStatus()
        }
        .alert(statusMessage ?? "", isPresented: $showStatus) {
            Button("OK", role: .cancel) {}
        }
    }

    private func checkInstallStatus() {
        serviceInstalled = printerService.isPDFServiceInstalled()
    }

    private func installPDFService() {
        isInstallingService = true
        let success = printerService.installPDFService()
        isInstallingService = false
        serviceInstalled = success
        statusMessage = success ? "PDF Service installed successfully. 'Save to PandyDoc' is now available in print dialogs." : "Failed to install PDF Service"
        showStatus = true
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
