import SwiftUI

struct ContentView: View {
    @StateObject private var store = ProjectStore()

    var body: some View {
        TabView {
            ProjectsListView()
                .tabItem {
                    Label("Projects", systemImage: "list.bullet")
                }

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
        }
        .environmentObject(store)
        .tint(KnitTheme.rose)
    }
}
