import PhotosUI
import SwiftUI
import UIKit

struct NewProjectView: View {
    @EnvironmentObject var store: ProjectStore
    @Environment(\.dismiss) var dismiss

    let onCreate: (KnitProject) -> Void
    
    @State private var name = ""
    @State private var notes = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var showingPhotoOptions = false
    @State private var showingPhotoLibrary = false
    @State private var showingCamera = false
    @State private var showingCameraUnavailableAlert = false
    
    var canCreate: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    
    var body: some View {
        NavigationStack {
            ZStack {
                KnitTheme.cream.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        Button {
                            showingPhotoOptions = true
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(KnitTheme.roseLight.opacity(0.5))
                                    .frame(height: 160)

                                if let selectedPhotoData,
                                   let uiImage = UIImage(data: selectedPhotoData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 160)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                        .overlay(alignment: .bottomTrailing) {
                                            photoBadge(title: "Change Photo", icon: "photo")
                                                .padding(12)
                                        }
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(KnitTheme.roseMid)
                                        Text("Add Photo")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(KnitTheme.taupe)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                        
                        // Form fields
                        VStack(spacing: 14) {
                            FormField(label: "Project Name", placeholder: "e.g. Cable Sweater", text: $name)
                            FormField(label: "Notes (optional)", placeholder: "Add any notes about this project...", text: $notes, isMultiline: true)
                        }
                        
                        Button("Create") {
                            var project = KnitProject(name: name, notes: notes)
                            if let selectedPhotoData {
                                project.photoData = [selectedPhotoData]
                            }
                            store.addProject(project)
                            onCreate(project)
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canCreate)
                        .opacity(canCreate ? 1 : 0.5)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(KnitTheme.rose)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else {
                    return
                }
                Task {
                    let loadedData = try? await newItem.loadTransferable(type: Data.self)
                    await MainActor.run {
                        selectedPhotoData = normalizedPhotoData(from: loadedData)
                    }
                }
            }
            .confirmationDialog("Add Photo", isPresented: $showingPhotoOptions, titleVisibility: .visible) {
                Button("Take Photo") {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showingCamera = true
                    } else {
                        showingCameraUnavailableAlert = true
                    }
                }

                Button("Choose from Library") {
                    showingPhotoLibrary = true
                }

                if selectedPhotoData != nil {
                    Button("Remove Photo", role: .destructive) {
                        selectedPhotoData = nil
                        selectedPhotoItem = nil
                    }
                }

                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(isPresented: $showingPhotoLibrary, selection: $selectedPhotoItem, matching: .images)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraImagePicker(selectedPhotoData: $selectedPhotoData)
                    .ignoresSafeArea()
            }
            .alert("Camera Unavailable", isPresented: $showingCameraUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Use a real device to take a new photo, or choose one from your photo library.")
            }
        }
    }

    init(onCreate: @escaping (KnitProject) -> Void = { _ in }) {
        self.onCreate = onCreate
    }

    @ViewBuilder
    private func photoBadge(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(KnitTheme.brown.opacity(0.7))
        .clipShape(Capsule())
    }

    private func normalizedPhotoData(from data: Data?) -> Data? {
        guard let data,
              let image = UIImage(data: data) else {
            return data
        }

        return image.jpegData(compressionQuality: 0.82) ?? data
    }
}

struct CameraImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPhotoData: Data?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedPhotoData: $selectedPhotoData, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @Binding private var selectedPhotoData: Data?
        private let dismiss: DismissAction

        init(selectedPhotoData: Binding<Data?>, dismiss: DismissAction) {
            self._selectedPhotoData = selectedPhotoData
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            selectedPhotoData = image?.jpegData(compressionQuality: 0.82)
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

// MARK: - Form Field

struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isMultiline = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: label)
            
            if isMultiline {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 15))
                            .foregroundColor(KnitTheme.taupe.opacity(0.5))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $text)
                        .font(.system(size: 15))
                        .foregroundColor(KnitTheme.brown)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                }
                .padding(12)
                .background(KnitTheme.warmWhite)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(KnitTheme.divider, lineWidth: 1))
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(size: 15))
                    .foregroundColor(KnitTheme.brown)
                    .padding(14)
                    .background(KnitTheme.warmWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(KnitTheme.divider, lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardStyle()
    }
}
