import SwiftUI

struct CheckInSheetView: View {
    @ObservedObject var viewModel: DocumentListViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Check In Document") {
                    if let doc = viewModel.selectedDocument {
                        Text(doc.name)
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Change Notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $viewModel.checkInNotes)
                            .frame(minHeight: 100)
                            .border(Color.gray.opacity(0.3))
                    }
                }
            }
            .formStyle(.grouped)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Check In") {
                        if let doc = viewModel.selectedDocument {
                            viewModel.performCheckIn(document: doc)
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
        }
        .frame(width: 400, height: 300)
    }
}
