import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// MARK: - PDF Import View (from Project)

struct PDFImportView: View {
    @Binding var project: KnitProject
    @Environment(\.dismiss) var dismiss
    let onSave: (ImportedPDF.ID) -> Void
    
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                KnitTheme.cream.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Drop zone
                    Button {
                        showingFilePicker = true
                    } label: {
                        VStack(spacing: 14) {
                            Image(systemName: "arrow.up.doc.fill")
                                .font(.system(size: 44))
                                .foregroundColor(KnitTheme.rose)
                            Text("Import PDF")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(KnitTheme.brown)
                            Text("Choose a PDF pattern from your device")
                                .font(.system(size: 14))
                                .foregroundColor(KnitTheme.taupe)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(KnitTheme.warmWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(KnitTheme.roseMid, style: StrokeStyle(lineWidth: 1.5, dash: [8]))
                        )
                    }
                    
                    // Tips
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tips")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(KnitTheme.brown)
                        ForEach(["Make sure your PDF is clear and legible",
                                 "Larger text may be easier to read",
                                 "You can annotate and track rows"], id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(KnitTheme.sage)
                                Text(tip)
                                    .font(.system(size: 14))
                                    .foregroundColor(KnitTheme.taupe)
                            }
                        }
                    }
                    .padding(16)
                    .cardStyle()
                    
                    Spacer()
                    
                    Button("Choose PDF") {
                        showingFilePicker = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .navigationTitle("Import PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(KnitTheme.rose)
                }
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            PDFDocumentPicker { data, name in
                let pdf = ImportedPDF(name: name, pdfData: data)
                project.importedPDFs.append(pdf)
                onSave(pdf.id)
                showingFilePicker = false

                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - PDF Document Picker

struct PDFDocumentPicker: UIViewControllerRepresentable {
    let onPick: (Data, String) -> Void
    
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Data, String) -> Void
        init(onPick: @escaping (Data, String) -> Void) { self.onPick = onPick }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            
            if let data = try? Data(contentsOf: url) {
                onPick(data, url.lastPathComponent)
            }
        }
    }
}
