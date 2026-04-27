import SwiftUI
import PDFKit

struct PDFViewerView: View {
    @Binding var pdf: ImportedPDF
    @Binding var rowSections: [RowSection]
    @Environment(\.dismiss) var dismiss

    let onSave: () -> Void

    @State private var currentPage: Int
    @State private var totalPages = 0
    @State private var selectedTool: AnnotationTool = .none
    @State private var rowCounter: Int
    @State private var showingRowCounter = true
    @State private var rowRangeStart: Int
    @State private var rowRangeEnd: Int
    @State private var highlightColorIndex = 1
    @State private var penColorIndex = 0
    @State private var annotationCommand: AnnotationCommand?
    @State private var floatingCounterPosition: CGPoint = .zero
    @State private var useLargeCounterWidget = false
    @State private var dockCounterToBottom = false
    @GestureState private var floatingCounterDrag: CGSize = .zero
    @State private var containerSize: CGSize = .zero

    enum AnnotationTool: String, CaseIterable {
        case none = "none"
        case highlight = "Highlight"
        case pen = "Pen"

        var icon: String {
            switch self {
            case .none:
                return "hand.point.up"
            case .highlight:
                return "highlighter"
            case .pen:
                return "pencil.tip"
            }
        }
    }

    struct AnnotationCommand: Equatable {
        enum Kind: Equatable {
            case undoLatest
        }

        let kind: Kind
        let id = UUID()
    }

    let highlightColors: [CodableColor] = [
        .roseHighlight,
        .yellowHighlight,
        .greenHighlight,
        .blueHighlight
    ]

    let penColors: [CodableColor] = [
        CodableColor(red: 0.72, green: 0.42, blue: 0.42, alpha: 1),
        CodableColor(red: 0.38, green: 0.56, blue: 0.84, alpha: 1),
        CodableColor(red: 0.36, green: 0.66, blue: 0.48, alpha: 1),
        CodableColor(red: 0.40, green: 0.31, blue: 0.28, alpha: 1)
    ]

    var activeAnnotationColor: CodableColor {
        switch selectedTool {
        case .highlight:
            return highlightColors[highlightColorIndex]
        case .pen:
            return penColors[penColorIndex]
        case .none:
            return highlightColors[highlightColorIndex]
        }
    }

    init(pdf: Binding<ImportedPDF>, rowSections: Binding<[RowSection]>, onSave: @escaping () -> Void = {}) {
        self._pdf = pdf
        self._rowSections = rowSections
        self.onSave = onSave

        let value = pdf.wrappedValue
        self._currentPage = State(initialValue: value.currentPage)
        self._rowCounter = State(initialValue: value.rowCounter)
        self._rowRangeStart = State(initialValue: value.rowRangeStart)
        self._rowRangeEnd = State(initialValue: max(value.rowRangeEnd, value.rowRangeStart))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            viewerBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topToolbar
                PDFKitView(
                    pdfData: $pdf.pdfData,
                    highlights: $pdf.highlights,
                    currentPage: $currentPage,
                    totalPages: $totalPages,
                    selectedTool: selectedTool,
                    annotationColor: activeAnnotationColor,
                    annotationCommand: annotationCommand,
                    onDocumentChange: onSave
                )
                    .background(KnitTheme.cream)
                bottomBar
            }

            if showingRowCounter {
                GeometryReader { geo in
                    floatingCounter(in: geo.size)
                        .onAppear { containerSize = geo.size }
                        .onChange(of: geo.size) { containerSize = geo.size }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: currentPage) { persistPDFState() }
        .onChange(of: rowCounter) { persistPDFState() }
        .onChange(of: rowRangeStart) {
            if rowRangeEnd < rowRangeStart {
                rowRangeEnd = rowRangeStart
            }
            if rowCounter < rowRangeStart {
                rowCounter = rowRangeStart
            }
            persistPDFState()
        }
        .onChange(of: rowRangeEnd) {
            if rowCounter > rowRangeEnd {
                rowCounter = rowRangeEnd
            }
            persistPDFState()
        }
        .onDisappear {
            persistPDFState()
        }
        .onAppear {
            KnitHaptics.prepareCounterTap()
        }
    }

    var viewerBackground: some View {
        ZStack {
            LinearGradient(
                colors: [KnitTheme.cream, KnitTheme.warmWhite, KnitTheme.roseLight.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(KnitTheme.roseLight.opacity(0.35))
                .frame(width: 260, height: 260)
                .blur(radius: 30)
                .offset(x: -100, y: -220)

            Circle()
                .fill(KnitTheme.sage.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 36)
                .offset(x: 120, y: 320)
        }
    }

    var topToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(KnitTheme.brown)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(pdf.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(KnitTheme.brown)
                        .lineLimit(1)
                    Text("Page \(currentPage + 1) of \(max(totalPages, 1))")
                        .font(.system(size: 11))
                        .foregroundColor(KnitTheme.taupe)
                }

                Spacer()

                HStack(spacing: 8) {
                    toolbarModeButton(
                        icon: "arrow.uturn.backward",
                        isActive: false,
                        activeColor: KnitTheme.taupe,
                        action: undoLatestAnnotation
                    )

                    toolbarModeButton(
                        icon: "highlighter",
                        isActive: selectedTool == .highlight,
                        activeColor: KnitTheme.rose,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedTool == .highlight {
                                    selectedTool = .none
                                } else {
                                    selectedTool = .highlight
                                }
                            }
                        }
                    )

                    toolbarModeButton(
                        icon: "pencil.tip",
                        isActive: selectedTool == .pen,
                        activeColor: KnitTheme.rose,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedTool == .pen {
                                    selectedTool = .none
                                } else {
                                    selectedTool = .pen
                                }
                            }
                        }
                    )

                    toolbarModeButton(
                        icon: "list.number",
                        isActive: showingRowCounter,
                        activeColor: KnitTheme.sage,
                        showsCheckmark: true,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                showingRowCounter.toggle()
                            }
                        }
                    )
                }
            }

            if selectedTool != .none {
                HStack(spacing: 8) {
                    ForEach(activeToolColors.indices, id: \.self) { index in
                        colorMenuChip(
                            color: activeToolColors[index],
                            isSelected: activeColorIndex == index,
                            action: { selectColor(at: index) }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            KnitTheme.warmWhite.opacity(0.94)
                .shadow(color: KnitTheme.cardShadow, radius: 12, y: 6)
        )
    }

    var bottomBar: some View {
        HStack {
            HStack(spacing: 10) {
                Text("\(currentPage + 1) / \(max(totalPages, 1))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(KnitTheme.brown)

                Divider()
                    .frame(height: 18)

                HStack(spacing: 10) {
                    bottomPagerButton(systemName: "chevron.left", isEnabled: currentPage > 0) {
                        if currentPage > 0 {
                            currentPage -= 1
                        }
                    }

                    bottomPagerButton(systemName: "chevron.right", isEnabled: currentPage < totalPages - 1) {
                        if currentPage < totalPages - 1 {
                            currentPage += 1
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(KnitTheme.warmWhite.opacity(0.96))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(KnitTheme.divider.opacity(0.85), lineWidth: 1)
            )
            .shadow(color: KnitTheme.cardShadow, radius: 12, y: 4)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    func floatingCounter(in size: CGSize) -> some View {
        let basePosition = resolvedCounterPosition(in: size)
        let dockedY = size.height - counterWidgetSize.height / 2 - 48

        return counterWidget
            .frame(width: counterWidgetSize.width)
            .position(
                x: dockCounterToBottom ? size.width / 2 : basePosition.x + floatingCounterDrag.width,
                y: dockCounterToBottom ? dockedY : basePosition.y + floatingCounterDrag.height
            )
            .onAppear {
                if floatingCounterPosition == .zero {
                    floatingCounterPosition = defaultCounterPosition(in: size)
                }
            }
    }

    @ViewBuilder
    var counterWidget: some View {
        if rowSections.isEmpty {
            singleCounterWidget
        } else {
            rowSectionsCounterWidget
        }
    }

    var rowSectionsCounterWidget: some View {
        VStack(spacing: useLargeCounterWidget ? 14 : 10) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: useLargeCounterWidget ? 12 : 9, weight: .bold))
                    .foregroundColor(KnitTheme.taupe.opacity(0.85))
                Text("Row Counters")
                    .font(.system(size: useLargeCounterWidget ? 15 : 12, weight: .semibold))
                    .foregroundColor(KnitTheme.brown)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        useLargeCounterWidget.toggle()
                    }
                } label: {
                    Image(systemName: useLargeCounterWidget ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: useLargeCounterWidget ? 16 : 12, weight: .semibold))
                        .foregroundColor(KnitTheme.taupe)
                }
                if useLargeCounterWidget {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            dockCounterToBottom.toggle()
                        }
                    } label: {
                        Image(systemName: dockCounterToBottom ? "rectangle.bottomthird.inset.filled" : "rectangle.bottomthird.inset")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(dockCounterToBottom ? KnitTheme.rose : KnitTheme.taupe)
                    }
                }
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        showingRowCounter = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: useLargeCounterWidget ? 20 : 15))
                        .foregroundColor(KnitTheme.rose)
                }
            }
            .contentShape(Rectangle())
            .gesture(counterDragGesture)

            ScrollView {
                VStack(spacing: useLargeCounterWidget ? 12 : 8) {
                    ForEach(rowSections) { section in
                        if useLargeCounterWidget {
                            PDFRowSectionCounterCard(
                                section: section,
                                onDecrement: { updateSectionCounter(sectionID: section.id, delta: -1) },
                                onIncrement: { updateSectionCounter(sectionID: section.id, delta: 1) }
                            )
                        } else {
                            PDFCompactRowSectionCounterCard(
                                section: section,
                                onDecrement: { updateSectionCounter(sectionID: section.id, delta: -1) },
                                onIncrement: { updateSectionCounter(sectionID: section.id, delta: 1) }
                            )
                        }
                    }
                }
                .padding(.bottom, 2)
            }
            .frame(maxHeight: useLargeCounterWidget ? 470 : 164)
        }
        .padding(useLargeCounterWidget ? 16 : 9)
        .background(KnitTheme.warmWhite)
        .clipShape(RoundedRectangle(cornerRadius: useLargeCounterWidget ? 24 : 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 14, y: 4)
    }

    var singleCounterWidget: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(KnitTheme.taupe.opacity(0.85))
                Text("Row Counter")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(KnitTheme.brown)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        useLargeCounterWidget.toggle()
                    }
                } label: {
                    Image(systemName: useLargeCounterWidget ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(KnitTheme.taupe)
                }
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        dockCounterToBottom.toggle()
                    }
                } label: {
                    Image(systemName: dockCounterToBottom ? "rectangle.bottomthird.inset.filled" : "rectangle.bottomthird.inset")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(dockCounterToBottom ? KnitTheme.rose : KnitTheme.taupe)
                }
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        showingRowCounter = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(KnitTheme.rose)
                }
            }
            .contentShape(Rectangle())
            .gesture(counterDragGesture)

            Text("\(rowCounter)")
                .font(.system(size: 68, weight: .bold, design: .rounded))
                .foregroundColor(KnitTheme.brown)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.25), value: rowCounter)

            HStack(spacing: 48) {
                Button {
                    if rowCounter > rowRangeStart {
                        rowCounter -= 1
                    }
                    KnitHaptics.counterTap()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(KnitTheme.brown)
                        .frame(width: 64, height: 64)
                        .background(KnitTheme.roseLight)
                        .clipShape(Circle())
                }

                Button {
                    if rowCounter < rowRangeEnd {
                        rowCounter += 1
                    }
                    KnitHaptics.counterTap()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(KnitTheme.rose)
                        .clipShape(Circle())
                }
            }

            VStack(spacing: 10) {
                Text("Set Row Range")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(KnitTheme.taupe)

                HStack(spacing: 24) {
                    compactRangeEditor(title: "From", value: rowRangeStart) {
                        if rowRangeStart > 1 {
                            rowRangeStart -= 1
                        }
                    } onIncrease: {
                        rowRangeStart += 1
                    }

                    compactRangeEditor(title: "To", value: rowRangeEnd) {
                        if rowRangeEnd > rowRangeStart {
                            rowRangeEnd -= 1
                        }
                    } onIncrease: {
                        rowRangeEnd += 1
                    }
                }
            }

            Button("Reset Counter") {
                withAnimation {
                    rowCounter = rowRangeStart
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(KnitTheme.taupe.opacity(0.82))
        }
        .padding(20)
        .background(KnitTheme.warmWhite)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 14, y: 4)
    }

    var counterDragGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .updating($floatingCounterDrag) { value, state, _ in
                if !dockCounterToBottom {
                    state = value.translation
                }
            }
            .onEnded { value in
                guard !dockCounterToBottom else { return }
                let size = containerSize == .zero ? UIScreen.main.bounds.size : containerSize
                let current = floatingCounterPosition == .zero ? defaultCounterPosition(in: size) : floatingCounterPosition
                let proposed = CGPoint(
                    x: current.x + value.translation.width,
                    y: current.y + value.translation.height
                )
                floatingCounterPosition = clampedCounterPosition(proposed, in: size)
            }
    }

    func defaultCounterPosition(in size: CGSize) -> CGPoint {
        let widgetSize = counterWidgetSize
        return CGPoint(
            x: size.width - widgetSize.width / 2 - 18,
            y: size.height - widgetSize.height / 2 - 96
        )
    }

    func resolvedCounterPosition(in size: CGSize) -> CGPoint {
        let current = floatingCounterPosition == .zero ? defaultCounterPosition(in: size) : floatingCounterPosition
        return clampedCounterPosition(current, in: size)
    }

    func clampedCounterPosition(_ position: CGPoint, in size: CGSize) -> CGPoint {
        let widgetSize = counterWidgetSize
        let horizontalPadding: CGFloat = 14
        let topPadding: CGFloat = 86
        let bottomPadding: CGFloat = 44

        let minX = widgetSize.width / 2 + horizontalPadding
        let maxX = size.width - widgetSize.width / 2 - horizontalPadding
        let minY = widgetSize.height / 2 + topPadding
        let maxY = size.height - widgetSize.height / 2 - bottomPadding

        return CGPoint(
            x: min(max(position.x, minX), maxX),
            y: min(max(position.y, minY), maxY)
        )
    }

    var counterWidgetSize: CGSize {
        if rowSections.isEmpty {
            return useLargeCounterWidget ? CGSize(width: 300, height: 360) : CGSize(width: 250, height: 320)
        }
        return useLargeCounterWidget ? CGSize(width: 390, height: 560) : CGSize(width: 272, height: 188)
    }

    func toolbarModeButton(
        icon: String,
        isActive: Bool,
        activeColor: Color,
        showsCheckmark: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isActive ? .white : KnitTheme.brown)
                    .frame(width: 38, height: 38)
                    .background(isActive ? activeColor : KnitTheme.warmWhite.opacity(0.96))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isActive ? Color.clear : KnitTheme.divider, lineWidth: 1)
                    )

                if showsCheckmark && isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(activeColor)
                                .frame(width: 12, height: 12)
                        )
                        .offset(x: 2, y: 2)
                }
            }
            .shadow(color: isActive ? activeColor.opacity(0.2) : KnitTheme.cardShadow, radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    var activeToolColors: [CodableColor] {
        switch selectedTool {
        case .highlight:
            return highlightColors
        case .pen:
            return penColors
        case .none:
            return []
        }
    }

    var activeColorIndex: Int {
        switch selectedTool {
        case .highlight:
            return highlightColorIndex
        case .pen:
            return penColorIndex
        case .none:
            return 0
        }
    }

    func selectColor(at index: Int) {
        switch selectedTool {
        case .highlight:
            highlightColorIndex = index
        case .pen:
            penColorIndex = index
        case .none:
            break
        }
    }

    func colorMenuChip(color: CodableColor, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color.color)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(isSelected ? KnitTheme.brown : KnitTheme.divider, lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    func undoLatestAnnotation() {
        annotationCommand = AnnotationCommand(kind: .undoLatest)
    }

    func bottomPagerButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isEnabled ? KnitTheme.brown : KnitTheme.taupe.opacity(0.4))
                .frame(width: 30, height: 30)
                .background(isEnabled ? KnitTheme.roseLight.opacity(0.7) : KnitTheme.cream)
                .clipShape(Circle())
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }

    func compactRangeEditor(
        title: String,
        value: Int,
        onDecrease: @escaping () -> Void,
        onIncrease: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(KnitTheme.taupe)
            HStack(spacing: 8) {
                CounterButton(systemName: "minus", action: onDecrease)
                Text("\(value)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(KnitTheme.brown)
                    .frame(minWidth: 24)
                CounterButton(systemName: "plus", action: onIncrease)
            }
        }
    }

    func updateSectionCounter(sectionID: RowSection.ID, delta: Int) {
        guard let index = rowSections.firstIndex(where: { $0.id == sectionID }) else { return }

        let start = rowSections[index].startRow ?? 1
        let end = rowSections[index].endRow
        let candidate = rowSections[index].currentRow + delta
        let lowerClamped = max(candidate, start)
        let newValue = min(lowerClamped, end ?? lowerClamped)

        guard newValue != rowSections[index].currentRow else { return }

        rowSections[index].currentRow = newValue
        rowSections[index].isCompleted = end.map { newValue >= $0 } ?? false
        KnitHaptics.counterTap()
        onSave()
    }

    func persistPDFState() {
        pdf.currentPage = currentPage
        pdf.rowCounter = rowCounter
        pdf.rowRangeStart = rowRangeStart
        pdf.rowRangeEnd = max(rowRangeEnd, rowRangeStart)
        onSave()
    }
}

struct PDFKitView: UIViewRepresentable {
    @Binding var pdfData: Data
    @Binding var highlights: [PDFHighlight]
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    let selectedTool: PDFViewerView.AnnotationTool
    let annotationColor: CodableColor
    let annotationCommand: PDFViewerView.AnnotationCommand?
    let onDocumentChange: () -> Void

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true)
        pdfView.backgroundColor = UIColor(KnitTheme.cream)
        pdfView.displaysPageBreaks = false

        if let document = PDFDocument(data: pdfData) {
            pdfView.document = document
            DispatchQueue.main.async {
                totalPages = document.pageCount
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        context.coordinator.installGestures(on: pdfView)
        context.coordinator.pdfView = pdfView
        context.coordinator.highlights = $highlights
        context.coordinator.pdfData = $pdfData
        context.coordinator.updateInteractionMode(selectedTool: selectedTool, annotationColor: annotationColor)
        context.coordinator.handle(command: annotationCommand)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.pdfView = pdfView
        context.coordinator.highlights = $highlights
        context.coordinator.pdfData = $pdfData
        context.coordinator.updateInteractionMode(selectedTool: selectedTool, annotationColor: annotationColor)
        context.coordinator.handle(command: annotationCommand)

        if let document = pdfView.document,
           currentPage >= 0,
           currentPage < document.pageCount,
           let page = document.page(at: currentPage),
           pdfView.currentPage != page {
            pdfView.go(to: page)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            currentPage: $currentPage,
            totalPages: $totalPages,
            pdfData: $pdfData,
            highlights: $highlights,
            onDocumentChange: onDocumentChange
        )
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        @Binding var currentPage: Int
        @Binding var totalPages: Int
        var pdfData: Binding<Data>
        var highlights: Binding<[PDFHighlight]>
        let onDocumentChange: () -> Void
        weak var pdfView: PDFView?
        private var currentTool: PDFViewerView.AnnotationTool = .none
        private var currentAnnotationColor: CodableColor = .yellowHighlight
        private weak var panGesture: UIPanGestureRecognizer?
        private weak var activePage: PDFPage?
        private var activeAnnotation: PDFKit.PDFAnnotation?
        private var dragStartPoint: CGPoint?
        private var drawPath = UIBezierPath()
        private var handledCommandID: UUID?

        init(
            currentPage: Binding<Int>,
            totalPages: Binding<Int>,
            pdfData: Binding<Data>,
            highlights: Binding<[PDFHighlight]>,
            onDocumentChange: @escaping () -> Void
        ) {
            self._currentPage = currentPage
            self._totalPages = totalPages
            self.pdfData = pdfData
            self.highlights = highlights
            self.onDocumentChange = onDocumentChange
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = pdfView,
                  let page = pdfView.currentPage,
                  let document = pdfView.document else { return }

            DispatchQueue.main.async {
                self.currentPage = document.index(for: page)
                self.totalPages = document.pageCount
            }
        }

        func installGestures(on pdfView: PDFView) {
            guard panGesture == nil else { return }

            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            panGesture.delegate = self
            panGesture.maximumNumberOfTouches = 1
            pdfView.addGestureRecognizer(panGesture)
            self.panGesture = panGesture
        }

        func updateInteractionMode(selectedTool: PDFViewerView.AnnotationTool, annotationColor: CodableColor) {
            if currentTool != selectedTool {
                cancelActiveAnnotation()
            }

            currentTool = selectedTool
            currentAnnotationColor = annotationColor

            findScrollView(in: pdfView)?.isScrollEnabled = selectedTool == .none

            if selectedTool == .none {
                cancelActiveAnnotation()
            }
        }

        func handle(command: PDFViewerView.AnnotationCommand?) {
            guard let command else { return }
            guard handledCommandID != command.id else { return }
            handledCommandID = command.id

            switch command.kind {
            case .undoLatest:
                removeLastAnnotation()
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            currentTool != .none
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard currentTool != .none, let pdfView else { return }

            let location = gesture.location(in: pdfView)

            switch gesture.state {
            case .began:
                beginGesture(at: location, in: pdfView)
            case .changed:
                updateGesture(at: location, in: pdfView)
            case .ended:
                finishGesture(at: location, in: pdfView)
            case .cancelled, .failed:
                cancelActiveAnnotation()
            default:
                break
            }
        }

        func beginGesture(at viewPoint: CGPoint, in pdfView: PDFView) {
            guard let page = pdfView.page(for: viewPoint, nearest: true) else { return }

            activePage = page
            let pagePoint = pdfView.convert(viewPoint, to: page)

            switch currentTool {
            case .highlight:
                dragStartPoint = pagePoint
                let annotation = makeHighlightAnnotation(for: CGRect(origin: pagePoint, size: CGSize(width: 1, height: 1)))
                page.addAnnotation(annotation)
                activeAnnotation = annotation
            case .pen:
                dragStartPoint = pagePoint
                drawPath = UIBezierPath()
                drawPath.move(to: pagePoint)
                let annotation = makeInkAnnotation(from: drawPath)
                page.addAnnotation(annotation)
                activeAnnotation = annotation
            case .none:
                break
            }
        }

        func updateGesture(at viewPoint: CGPoint, in pdfView: PDFView) {
            guard let page = activePage ?? pdfView.page(for: viewPoint, nearest: true) else { return }
            let pagePoint = pdfView.convert(viewPoint, to: page)

            switch currentTool {
            case .highlight:
                guard let start = dragStartPoint,
                      let annotation = activeAnnotation else { return }
                annotation.bounds = normalizedRect(from: start, to: pagePoint)
            case .pen:
                guard let activePage,
                      activePage == page else { return }
                drawPath.addLine(to: pagePoint)
                replaceInkAnnotation(on: activePage)
            case .none:
                break
            }
        }

        func finishGesture(at viewPoint: CGPoint, in pdfView: PDFView) {
            updateGesture(at: viewPoint, in: pdfView)
            persistDocumentState()
            resetGestureState()
        }

        func cancelActiveAnnotation() {
            if let activeAnnotation, let activePage {
                activePage.removeAnnotation(activeAnnotation)
            }
            resetGestureState()
        }

        func resetGestureState() {
            activePage = nil
            activeAnnotation = nil
            dragStartPoint = nil
            drawPath = UIBezierPath()
        }

        func makeHighlightAnnotation(for rect: CGRect) -> PDFKit.PDFAnnotation {
            let annotation = PDFKit.PDFAnnotation(bounds: rect, forType: .square, withProperties: nil)
            annotation.color = .clear
            annotation.interiorColor = UIColor(currentAnnotationColor.color)
            annotation.border = PDFBorder()
            annotation.border?.lineWidth = 0
            annotation.userName = "NeedleNoteHighlight"
            return annotation
        }

        func makeInkAnnotation(from path: UIBezierPath) -> PDFKit.PDFAnnotation {
            let bounds = path.cgPath.boundingBoxOfPath.insetBy(dx: -4, dy: -4)
            let annotation = PDFKit.PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
            annotation.color = UIColor(
                red: currentAnnotationColor.red,
                green: currentAnnotationColor.green,
                blue: currentAnnotationColor.blue,
                alpha: 0.95
            )
            annotation.border = PDFBorder()
            annotation.border?.lineWidth = 3

            let translatedPath = UIBezierPath(cgPath: path.cgPath)
            translatedPath.apply(CGAffineTransform(translationX: -bounds.origin.x, y: -bounds.origin.y))
            annotation.add(translatedPath)
            annotation.userName = "NeedleNoteInk"
            return annotation
        }

        func replaceInkAnnotation(on page: PDFPage) {
            if let activeAnnotation {
                page.removeAnnotation(activeAnnotation)
            }

            let annotation = makeInkAnnotation(from: drawPath)
            page.addAnnotation(annotation)
            activeAnnotation = annotation
        }

        func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
            CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: max(abs(end.x - start.x), 12),
                height: max(abs(end.y - start.y), 12)
            )
        }

        func persistDocumentState() {
            guard let pdfView,
                  let document = pdfView.document,
                  let data = document.dataRepresentation() else { return }

            pdfData.wrappedValue = data
            highlights.wrappedValue = serializedHighlights(from: document)
            DispatchQueue.main.async {
                self.onDocumentChange()
            }
        }

        func removeLastAnnotation() {
            guard let document = pdfView?.document else { return }

            for pageIndex in stride(from: document.pageCount - 1, through: 0, by: -1) {
                guard let page = document.page(at: pageIndex) else { continue }
                if let annotation = page.annotations.last(where: {
                    $0.userName == "NeedleNoteHighlight" || $0.userName == "NeedleNoteInk"
                }) {
                    page.removeAnnotation(annotation)
                    persistDocumentState()
                    return
                }
            }
        }

        func serializedHighlights(from document: PDFDocument) -> [PDFHighlight] {
            var results: [PDFHighlight] = []

            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }

                for annotation in page.annotations where annotation.userName == "NeedleNoteHighlight" {
                    results.append(
                        PDFHighlight(
                            page: pageIndex,
                            rect: CodableRect(
                                x: annotation.bounds.origin.x,
                                y: annotation.bounds.origin.y,
                                width: annotation.bounds.width,
                                height: annotation.bounds.height
                            ),
                            color: codableColor(from: annotation.interiorColor ?? UIColor(currentAnnotationColor.color))
                        )
                    )
                }
            }

            return results
        }

        func codableColor(from color: UIColor) -> CodableColor {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return CodableColor(red: red, green: green, blue: blue, alpha: alpha)
        }

        func findScrollView(in view: UIView?) -> UIScrollView? {
            guard let view else { return nil }
            if let scrollView = view as? UIScrollView {
                return scrollView
            }

            for subview in view.subviews {
                if let scrollView = findScrollView(in: subview) {
                    return scrollView
                }
            }

            return nil
        }
    }
}

struct PDFRowSectionCounterCard: View {
    let section: RowSection
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(section.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(KnitTheme.brown)
                    if section.totalRows > 0 {
                        Text(section.rowRange)
                            .font(.system(size: 13))
                            .foregroundColor(KnitTheme.taupe)
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    CounterButton(systemName: "minus", action: onDecrement)

                    Text("\(section.currentRow)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(KnitTheme.brown)
                        .frame(minWidth: 72)

                    CounterButton(systemName: "plus", action: onIncrement)
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
        .background(KnitTheme.warmWhite)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KnitTheme.cream, lineWidth: 1)
        )
    }
}

struct PDFCompactRowSectionCounterCard: View {
    let section: RowSection
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(section.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(KnitTheme.brown)
                .lineLimit(1)

            Spacer(minLength: 2)

            compactCounterButton(systemName: "minus", action: onDecrement)

            Text("\(section.currentRow)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(KnitTheme.brown)
                .frame(minWidth: 34)

            compactCounterButton(systemName: "plus", action: onIncrement)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(KnitTheme.warmWhite.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(KnitTheme.divider.opacity(0.8), lineWidth: 1)
        )
    }

    func compactCounterButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(KnitTheme.brown)
                .frame(width: 28, height: 28)
                .background(KnitTheme.roseLight.opacity(0.55))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

