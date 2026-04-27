import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var store: ProjectStore

    var allPDFs: [(projectID: KnitProject.ID, projectName: String, pdfID: ImportedPDF.ID)] {
        store.projects.flatMap { project in
            project.importedPDFs.map { pdf in
                (project.id, project.name, pdf.id)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KnitTheme.cream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        if allPDFs.isEmpty {
                            emptyPDFState
                        } else {
                            ForEach(allPDFs, id: \.pdfID) { item in
                                PDFLibraryRow(
                                    projectID: item.projectID,
                                    pdfID: item.pdfID,
                                    projectName: item.projectName
                                )
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    var emptyPDFState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.fill")
                .font(.system(size: 48))
                .foregroundColor(KnitTheme.roseMid)
            Text("No PDFs yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(KnitTheme.brown)
            Text("Import pattern PDFs from inside a project to keep them attached to that project.")
                .font(.system(size: 14))
                .foregroundColor(KnitTheme.taupe)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

struct PDFLibraryRow: View {
    @EnvironmentObject var store: ProjectStore

    let projectID: KnitProject.ID
    let pdfID: ImportedPDF.ID
    let projectName: String

    @State private var showViewer = false

    var pdf: ImportedPDF? {
        guard let projectIndex = store.projects.firstIndex(where: { $0.id == projectID }),
              let pdfIndex = store.projects[projectIndex].importedPDFs.firstIndex(where: { $0.id == pdfID }) else {
            return nil
        }

        return store.projects[projectIndex].importedPDFs[pdfIndex]
    }

    var body: some View {
        if let pdf {
            Button {
                showViewer = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 24))
                        .foregroundColor(KnitTheme.rose)
                        .frame(width: 44, height: 44)
                        .background(KnitTheme.roseLight)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(pdf.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(KnitTheme.brown)
                        Text("Added \(pdf.dateAdded.relativeString) · \(projectName)")
                            .font(.system(size: 12))
                            .foregroundColor(KnitTheme.taupe)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(KnitTheme.roseMid)
                }
                .padding(14)
                .cardStyle()
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $showViewer) {
                if let projectIndex = store.projects.firstIndex(where: { $0.id == projectID }),
                   let pdfIndex = store.projects[projectIndex].importedPDFs.firstIndex(where: { $0.id == pdfID }) {
                    PDFViewerView(
                        pdf: $store.projects[projectIndex].importedPDFs[pdfIndex],
                        rowSections: $store.projects[projectIndex].rowSections
                    ) {
                        store.updateProject(store.projects[projectIndex])
                    }
                } else {
                    ZStack {
                        KnitTheme.cream.ignoresSafeArea()
                        Text("Pattern unavailable")
                            .foregroundColor(KnitTheme.taupe)
                    }
                }
            }
        }
    }
}
