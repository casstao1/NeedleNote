import SwiftUI

struct ContentView: View {
    @StateObject private var store = ProjectStore()
    @StateObject private var purchases = PurchaseManager()

    var body: some View {
        rootContent
        .environmentObject(store)
        .environmentObject(purchases)
        .tint(KnitTheme.rose)
        .task {
            await purchases.start()
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        if let scenario = ProcessInfo.processInfo.environment["NEEDLENOTE_SCREENSHOT"] {
            ScreenshotScenarioView(scenario: scenario)
        } else {
            ProjectsListView()
        }
        #else
        ProjectsListView()
        #endif
    }
}

#if DEBUG
private struct ScreenshotScenarioView: View {
    let scenario: String

    var body: some View {
        switch scenario {
        case "paywall":
            PaywallView {}
        case "new-project":
            NewProjectView()
        case "rows":
            NavigationStack {
                ProjectDetailView(project: ScreenshotFixtures.project, initialTab: .rows)
            }
        case "patterns":
            NavigationStack {
                ProjectDetailView(project: ScreenshotFixtures.project, initialTab: .patterns)
            }
        case "notes":
            NavigationStack {
                ProjectDetailView(project: ScreenshotFixtures.project, initialTab: .notes)
            }
        case "pdf":
            ScreenshotPDFViewer()
        default:
            ProjectsListView()
        }
    }
}

private struct ScreenshotPDFViewer: View {
    @State private var pdf = ScreenshotFixtures.samplePDF
    @State private var rows = ScreenshotFixtures.project.rowSections

    var body: some View {
        PDFViewerView(pdf: $pdf, rowSections: $rows)
    }
}

private enum ScreenshotFixtures {
    static var project: KnitProject {
        KnitProject(
            name: "Cable Sweater",
            notes: "Cream wool cardigan with a ribbed hem, simple shaping, and a clean neckline.",
            rowSections: [
                RowSection(name: "Ribbing", startRow: 1, endRow: 16, currentRow: 15),
                RowSection(name: "Body", startRow: 17, endRow: 98, currentRow: 58),
                RowSection(name: "Armhole Shaping", startRow: 99, endRow: 122, currentRow: 99),
                RowSection(name: "Shoulders", startRow: 123, endRow: 138, currentRow: 123),
                RowSection(name: "Neckband", startRow: 139, endRow: 156, currentRow: 139)
            ],
            importedPDFs: [samplePDF]
        )
    }

    static var samplePDF: ImportedPDF {
        let data = Bundle.main.url(forResource: "NeedleNote-sample-pattern", withExtension: "pdf")
            .flatMap { try? Data(contentsOf: $0) } ?? Data()
        return ImportedPDF(name: "NeedleNote Sample Pattern.pdf", pdfData: data)
    }
}
#endif
