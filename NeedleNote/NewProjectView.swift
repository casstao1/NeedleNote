import PhotosUI
import SwiftUI

struct NewProjectView: View {
    @EnvironmentObject var store: ProjectStore
    @Environment(\.dismiss) var dismiss

    let onCreate: (KnitProject) -> Void
    
    @State private var name = ""
    @State private var notes = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    
    var canCreate: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    
    var body: some View {
        NavigationStack {
            ZStack {
                KnitTheme.cream.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
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
                    selectedPhotoData = nil
                    return
                }
                Task {
                    let loadedData = try? await newItem.loadTransferable(type: Data.self)
                    await MainActor.run {
                        selectedPhotoData = loadedData
                    }
                }
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
