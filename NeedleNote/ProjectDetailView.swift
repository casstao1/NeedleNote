import SwiftUI

struct ProjectDetailView: View {
    @EnvironmentObject var store: ProjectStore
    let project: KnitProject

    @State private var currentProject: KnitProject
    @State private var selectedTab: DetailTab = .rows
    @State private var showingAddSection = false
    @State private var editingSection: RowSection? = nil
    @State private var showingPDFPicker = false
    @State private var activePDFID: ImportedPDF.ID? = nil
    @State private var pendingImportedPDFID: ImportedPDF.ID?
    @State private var pendingNotesSaveTask: Task<Void, Never>?

    enum DetailTab: String, CaseIterable {
        case rows = "Rows"
        case patterns = "Patterns"
        case notes = "Notes"
    }

    init(project: KnitProject, initialTab: DetailTab = .rows) {
        self.project = project
        self._currentProject = State(initialValue: project)
        self._selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack {
            KnitTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                tabBar
                    .background(KnitTheme.warmWhite)

                Divider().foregroundColor(KnitTheme.divider)

                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case .rows:
                            rowsTab
                        case .patterns:
                            patternsTab
                        case .notes:
                            notesTab
                        }
                    }
                    .padding(16)
                    .padding(.bottom, bottomContentPadding)
                }
            }

            VStack {
                Spacer()
                Group {
                    if showsActionButton {
                        actionButton
                    }
                }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            }
        }
        .navigationTitle(currentProject.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .sheet(isPresented: $showingAddSection) {
            AddRowSectionView(project: $currentProject) {
                persistProjectChanges()
            }
        }
        .sheet(item: $editingSection) { section in
            EditRowSectionView(section: section, project: $currentProject) {
                persistProjectChanges()
            }
        }
        .sheet(isPresented: $showingPDFPicker) {
            PDFImportView(project: $currentProject) { importedPDFID in
                pendingImportedPDFID = importedPDFID
                persistProjectChanges()
            }
        }
        .fullScreenCover(isPresented: showingPDFViewer) {
            activePDFViewer
        }
        .onAppear {
            KnitHaptics.prepareCounterTap()
        }
        .onDisappear {
            pendingNotesSaveTask?.cancel()
            persistProjectChanges()
        }
        .onChange(of: showingPDFPicker) { _, isPresented in
            guard !isPresented, let importedPDFID = pendingImportedPDFID else { return }
            pendingImportedPDFID = nil
            activePDFID = importedPDFID
        }
    }

    var showingPDFViewer: Binding<Bool> {
        Binding(
            get: { activePDFID != nil },
            set: { isPresented in
                if !isPresented {
                    activePDFID = nil
                }
            }
        )
    }

    var activePDFIndex: Int? {
        guard let activePDFID else { return nil }
        return currentProject.importedPDFs.firstIndex(where: { $0.id == activePDFID })
    }

    @ViewBuilder
    var activePDFViewer: some View {
        if let activePDFIndex {
            PDFViewerView(pdf: $currentProject.importedPDFs[activePDFIndex], rowSections: $currentProject.rowSections) {
                persistProjectChanges()
            }
        } else {
            ZStack {
                KnitTheme.cream.ignoresSafeArea()
                Text("Pattern unavailable")
                    .foregroundColor(KnitTheme.taupe)
            }
            .onAppear {
                activePDFID = nil
            }
        }
    }

    var bottomContentPadding: CGFloat {
        var padding: CGFloat = 24

        if showsActionButton {
            padding += 92
        }

        return padding
    }

    var showsActionButton: Bool {
        selectedTab == .rows || selectedTab == .patterns
    }

    // MARK: - Tab Bar

    var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? KnitTheme.rose : KnitTheme.taupe)

                        Capsule()
                            .fill(selectedTab == tab ? KnitTheme.rose : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Rows Tab

    var rowsTab: some View {
        VStack(spacing: 12) {
            ForEach(currentProject.rowSections) { section in
                RowSectionCard(
                    section: section,
                    onEdit: { editingSection = section },
                    onDelete: { deleteSection(section) },
                    onDecrement: { updateSectionCounter(sectionID: section.id, delta: -1) },
                    onIncrement: { updateSectionCounter(sectionID: section.id, delta: 1) }
                )
            }

            if currentProject.rowSections.isEmpty {
                emptyRowsState
            }
        }
    }

    var emptyRowsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.number")
                .font(.system(size: 40))
                .foregroundColor(KnitTheme.roseMid)
            Text("No sections yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(KnitTheme.taupe)
            Text("Add row sections to track your progress.")
                .font(.system(size: 14))
                .foregroundColor(KnitTheme.taupe.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Patterns Tab

    var patternsTab: some View {
        VStack(spacing: 12) {
            if currentProject.importedPDFs.isEmpty {
                emptyPatternsState
            } else {
                ForEach(currentProject.importedPDFs) { pdf in
                    ProjectPDFRow(pdf: pdf) {
                        activePDFID = pdf.id
                    }
                }
            }
        }
    }

    var emptyPatternsState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.image")
                .font(.system(size: 40))
                .foregroundColor(KnitTheme.roseMid)
            Text("No pattern PDF yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(KnitTheme.brown)
            Text("Import the pattern inside this project so it stays attached here.")
                .font(.system(size: 14))
                .foregroundColor(KnitTheme.taupe.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Notes Tab

    var notesTab: some View {
        ZStack(alignment: .topLeading) {
            if currentProject.notes.isEmpty {
                Text("Tap to add notes about your project...")
                    .font(.system(size: 14))
                    .foregroundColor(KnitTheme.taupe.opacity(0.6))
                    .padding(.top, 18)
                    .padding(.leading, 20)
            }

            TextEditor(text: $currentProject.notes)
                .font(.system(size: 15))
                .foregroundColor(KnitTheme.brown)
                .frame(minHeight: 200)
                .padding(16)
                .background(KnitTheme.warmWhite)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .scrollContentBackground(.hidden)
                .onChange(of: currentProject.notes) {
                    scheduleNotesSave()
                }
        }
    }

    @ViewBuilder
    var actionButton: some View {
        switch selectedTab {
        case .rows:
            Button {
                showingAddSection = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Row Section")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

        case .patterns:
            Button {
                showingPDFPicker = true
            } label: {
                HStack {
                    Image(systemName: "doc.fill")
                    Text("Import PDF Into Project")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

        default:
            EmptyView()
        }
    }

    func persistProjectChanges() {
        pendingNotesSaveTask?.cancel()
        pendingNotesSaveTask = nil
        currentProject.lastWorked = Date()
        store.updateProject(currentProject)
    }

    func scheduleNotesSave() {
        pendingNotesSaveTask?.cancel()
        pendingNotesSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            persistProjectChanges()
        }
    }

    func deleteSection(_ section: RowSection) {
        currentProject.rowSections.removeAll { $0.id == section.id }
        persistProjectChanges()
    }

    func updateSectionCounter(sectionID: RowSection.ID, delta: Int) {
        guard let index = currentProject.rowSections.firstIndex(where: { $0.id == sectionID }) else { return }

        let start = currentProject.rowSections[index].startRow ?? 1
        let end = currentProject.rowSections[index].endRow
        let candidate = currentProject.rowSections[index].currentRow + delta
        let lowerClamped = max(candidate, start)
        let newValue = min(lowerClamped, end ?? lowerClamped)

        guard newValue != currentProject.rowSections[index].currentRow else { return }

        withAnimation(.spring(response: 0.25)) {
            currentProject.rowSections[index].currentRow = newValue
            currentProject.rowSections[index].isCompleted = end.map { newValue >= $0 } ?? false
            if currentProject.status == .notStarted {
                currentProject.status = .inProgress
            }
        }

        KnitHaptics.counterTap()
        persistProjectChanges()
    }
}

// MARK: - Row Section Card

struct RowSectionCard: View {
    let section: RowSection
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    @State private var settledOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0

    private let actionWidth: CGFloat = 168

    var currentOffset: CGFloat {
        min(0, max(-actionWidth, settledOffset + dragOffset))
    }

    var revealedWidth: CGFloat {
        max(0, -currentOffset)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(KnitTheme.warmWhite)
                .shadow(color: KnitTheme.cardShadow, radius: 8, x: 0, y: 2)

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    swipeActionButton(
                        systemImage: "pencil",
                        background: Color(red: 0.76, green: 0.71, blue: 0.68),
                        action: {
                            withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.88)) {
                                settledOffset = 0
                                dragOffset = 0
                            }
                            onEdit()
                        }
                    )

                    swipeActionButton(
                        systemImage: "trash",
                        background: Color(red: 0.84, green: 0.43, blue: 0.43),
                        action: {
                            withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.88)) {
                                settledOffset = 0
                                dragOffset = 0
                            }
                            onDelete()
                        }
                    )
                }
                .frame(width: actionWidth)
                .padding(.trailing, 6)
                .padding(.vertical, 6)
            }
            .background(KnitTheme.cream.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .mask(alignment: .trailing) {
                Rectangle()
                    .frame(width: revealedWidth)
            }

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(section.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(KnitTheme.brown)
                        if section.hasDefinedRange {
                            Text(section.rowRange)
                                .font(.system(size: 13))
                                .foregroundColor(KnitTheme.taupe)
                        }
                        if !section.notes.isEmpty {
                            Text(section.notes)
                                .font(.system(size: 12))
                                .foregroundColor(KnitTheme.taupe.opacity(0.8))
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 10) {
                        HStack(spacing: 10) {
                            CounterButton(systemName: "minus", action: onDecrement)

                            Text("\(section.currentRow)")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(KnitTheme.brown)
                                .frame(minWidth: 72)

                            CounterButton(systemName: "plus", action: onIncrement)
                        }
                    }
                }
                .padding(16)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(KnitTheme.roseLight).frame(height: 3)
                        if section.totalRows > 0 {
                            Rectangle()
                                .fill(section.isCompleted ? KnitTheme.sage : KnitTheme.rose)
                                .frame(width: geo.size.width * section.progress, height: 3)
                        }
                    }
                }
                .frame(height: 3)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(KnitTheme.warmWhite)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: KnitTheme.cardShadow, radius: 8, x: 0, y: 2)
            .offset(x: currentOffset)
            .simultaneousGesture(
                TapGesture().onEnded {
                    guard settledOffset != 0 else { return }
                    withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.88)) {
                        settledOffset = 0
                        dragOffset = 0
                    }
                }
            )
            .highPriorityGesture(rowSwipeGesture)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    var rowSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                let translation = value.translation.width
                if translation < 0 || settledOffset < 0 {
                    dragOffset = translation
                }
            }
            .onEnded { value in
                let predicted = settledOffset + value.predictedEndTranslation.width
                let shouldOpen = predicted < (-actionWidth * 0.45)

                withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.88)) {
                    settledOffset = shouldOpen ? -actionWidth : 0
                    dragOffset = 0
                }
            }
    }

    func swipeActionButton(systemImage: String, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 62)
            .frame(maxHeight: .infinity)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ProjectPDFRow: View {
    let pdf: ImportedPDF
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 22))
                    .foregroundColor(KnitTheme.rose)
                    .frame(width: 46, height: 46)
                    .background(KnitTheme.roseLight)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(pdf.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(KnitTheme.brown)
                        .lineLimit(1)
                    Text("Page \(pdf.currentPage + 1)")
                        .font(.system(size: 12))
                        .foregroundColor(KnitTheme.taupe)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(KnitTheme.roseMid)
            }
            .padding(14)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}
