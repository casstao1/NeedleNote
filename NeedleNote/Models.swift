import SwiftUI
import Foundation

// MARK: - Models

struct KnitProject: Identifiable, Codable {
    var id = UUID()
    var name: String
    var notes: String = ""
    var status: ProjectStatus = .notStarted
    var dateCreated: Date = Date()
    var lastWorked: Date = Date()
    var rowSections: [RowSection] = []
    var photoData: [Data] = []
    var importedPDFs: [ImportedPDF] = []
    
    enum ProjectStatus: String, Codable, CaseIterable {
        case notStarted = "Not Started"
        case inProgress = "In Progress"
        case completed = "Completed"
        
        var color: Color {
            switch self {
            case .notStarted: return KnitTheme.taupe
            case .inProgress: return KnitTheme.rose
            case .completed: return KnitTheme.sage
            }
        }
    }
}

struct RowSection: Identifiable, Codable {
    var id = UUID()
    var name: String
    var startRow: Int?
    var endRow: Int?
    var currentRow: Int
    var notes: String = ""
    var isCompleted: Bool = false

    var hasDefinedRange: Bool { startRow != nil || endRow != nil }

    var rowRange: String {
        switch (startRow, endRow) {
        case let (start?, end?):
            return "\(start) – \(end)"
        case let (start?, nil):
            return "Start \(start)"
        case let (nil, end?):
            return "Up to \(end)"
        case (nil, nil):
            return "No row range"
        }
    }

    var currentRowSummary: String {
        if let endRow {
            return "Row \(currentRow) of \(endRow)"
        }
        return "Row \(currentRow)"
    }

    var totalRows: Int {
        guard let startRow, let endRow, endRow >= startRow else { return 0 }
        return endRow - startRow + 1
    }

    var progress: Double {
        guard let startRow, let endRow, endRow >= startRow else { return 0 }
        let done = min(max(currentRow - startRow, 0), endRow - startRow + 1)
        return min(max(Double(done) / Double(totalRows), 0), 1)
    }
}

struct ImportedPDF: Identifiable, Codable {
    var id = UUID()
    var name: String
    var dateAdded: Date = Date()
    var pdfData: Data
    var annotations: [PDFAnnotation] = []
    var highlights: [PDFHighlight] = []
    var currentPage: Int = 0
    var rowCounter: Int = 1
    var rowRangeStart: Int = 1
    var rowRangeEnd: Int = 1
}

struct PDFAnnotation: Identifiable, Codable {
    var id = UUID()
    var page: Int
    var x: CGFloat
    var y: CGFloat
    var text: String
    var color: CodableColor
}

struct PDFHighlight: Identifiable, Codable {
    var id = UUID()
    var page: Int
    var rect: CodableRect
    var color: CodableColor
}

struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    
    var color: Color { Color(red: red, green: green, blue: blue).opacity(alpha) }
    
    static let roseHighlight = CodableColor(red: 0.78, green: 0.45, blue: 0.45, alpha: 0.35)
    static let yellowHighlight = CodableColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.4)
    static let greenHighlight = CodableColor(red: 0.4, green: 0.75, blue: 0.5, alpha: 0.35)
    static let blueHighlight = CodableColor(red: 0.35, green: 0.6, blue: 0.85, alpha: 0.35)
}

struct CodableRect: Codable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    
    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

// MARK: - Store

class ProjectStore: ObservableObject {
    @Published var projects: [KnitProject] = []
    
    private let saveKey = "NeedleNoteProjects"
    private let legacySaveKey = "KnitFlowProjects"
    private let bundledSamplePDFName = "NeedleNote Sample Pattern.pdf"
    
    init() {
        load()
        seedBundledSamplePDFIfNeeded()
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([KnitProject].self, from: data) {
            projects = decoded
        } else if let data = UserDefaults.standard.data(forKey: legacySaveKey),
                  let decoded = try? JSONDecoder().decode([KnitProject].self, from: data) {
            projects = decoded
            UserDefaults.standard.set(data, forKey: saveKey)
            UserDefaults.standard.removeObject(forKey: legacySaveKey)
        } else {
            // Sample data
            projects = [
                KnitProject(
                    name: "Cable Sweater",
                    notes: "Classic cable knit in cream wool",
                    status: .inProgress,
                    dateCreated: Date().addingTimeInterval(-1_296_000),
                    lastWorked: Date().addingTimeInterval(-86400),
                    rowSections: [
                        RowSection(name: "Ribbing", startRow: 1, endRow: 16, currentRow: 16, isCompleted: true),
                        RowSection(name: "Body", startRow: 17, endRow: 98, currentRow: 57),
                        RowSection(name: "Armhole Shaping", startRow: 99, endRow: 122, currentRow: 99),
                        RowSection(name: "Shoulders", startRow: 123, endRow: 138, currentRow: 123),
                        RowSection(name: "Neckband", startRow: 139, endRow: 156, currentRow: 139)
                    ]
                ),
                KnitProject(
                    name: "Lace Scarf",
                    status: .inProgress,
                    lastWorked: Date().addingTimeInterval(-172800),
                    rowSections: [
                        RowSection(name: "Main Pattern", startRow: 1, endRow: 120, currentRow: 45)
                    ]
                ),
                KnitProject(
                    name: "Baby Cardigan",
                    status: .notStarted,
                    lastWorked: Date().addingTimeInterval(-1_123_200),
                    rowSections: []
                )
            ]
        }
    }

    private func seedBundledSamplePDFIfNeeded() {
        guard !projects.contains(where: { project in
            project.importedPDFs.contains(where: { $0.name == bundledSamplePDFName })
        }) else { return }

        guard let url = Bundle.main.url(forResource: "NeedleNote-sample-pattern", withExtension: "pdf"),
              let data = try? Data(contentsOf: url) else { return }

        let samplePDF = ImportedPDF(name: bundledSamplePDFName, pdfData: data)

        if projects.isEmpty {
            projects = [KnitProject(name: "Sample Project", importedPDFs: [samplePDF])]
        } else {
            projects[0].importedPDFs.insert(samplePDF, at: 0)
        }

        save()
    }
    
    func addProject(_ project: KnitProject) {
        projects.insert(project, at: 0)
        save()
    }
    
    func updateProject(_ project: KnitProject) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
            save()
        }
    }
    
    func deleteProject(at offsets: IndexSet) {
        projects.remove(atOffsets: offsets)
        save()
    }
}
