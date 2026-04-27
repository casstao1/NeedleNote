import SwiftUI

// MARK: - Add Row Section

struct AddRowSectionView: View {
    @Binding var project: KnitProject
    @Environment(\.dismiss) var dismiss
    let onSave: () -> Void

    @State private var name = ""
    @State private var startRow: Int? = nil
    @State private var endRow: Int? = nil
    @State private var startingCounter = 1
    @State private var notes = ""

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !(startRow != nil && endRow != nil && endRow! < startRow!)
    }

    var minimumCounter: Int { startRow ?? 1 }
    var maximumCounter: Int? { endRow }

    var body: some View {
        NavigationStack {
            ZStack {
                KnitTheme.cream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        fieldCard {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeader(title: "Section Name")
                                TextField("e.g. Ribbing", text: $name)
                                    .font(.system(size: 15))
                                    .foregroundColor(KnitTheme.brown)
                            }
                        }

                        optionalBoundaryCard(
                            title: "Start Row",
                            isEnabled: startRowEnabled,
                            value: startRow,
                            emptyText: "Leave this off if the section does not need a lower boundary.",
                            onDecrease: {
                                guard let startRow, startRow > 1 else { return }
                                self.startRow = startRow - 1
                                startingCounter = max(startingCounter, self.startRow ?? 1)
                            },
                            onIncrease: {
                                let next = (startRow ?? max(1, min(startingCounter, endRow ?? startingCounter))) + 1
                                startRow = next
                                if let endRow, next > endRow {
                                    self.endRow = next
                                }
                                startingCounter = max(startingCounter, next)
                            }
                        )

                        optionalBoundaryCard(
                            title: "End Row",
                            isEnabled: endRowEnabled,
                            value: endRow,
                            emptyText: "Leave this off if you want the counter to keep increasing without an upper limit.",
                            onDecrease: {
                                guard let endRow else { return }
                                let minimumEnd = startRow ?? 1
                                guard endRow > minimumEnd else { return }
                                self.endRow = endRow - 1
                                if startingCounter > self.endRow ?? endRow {
                                    startingCounter = self.endRow ?? endRow
                                }
                            },
                            onIncrease: {
                                endRow = (endRow ?? max(startRow ?? 1, startingCounter)) + 1
                            }
                        )

                        fieldCard {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeader(title: "Starting Row Counter")
                                HStack {
                                    Text("\(startingCounter)")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(KnitTheme.brown)
                                    Spacer()
                                    HStack(spacing: 12) {
                                        CounterButton(systemName: "minus") {
                                            if startingCounter > minimumCounter {
                                                startingCounter -= 1
                                            }
                                        }
                                        CounterButton(systemName: "plus") {
                                            if let maximumCounter {
                                                if startingCounter < maximumCounter {
                                                    startingCounter += 1
                                                }
                                            } else {
                                                startingCounter += 1
                                            }
                                        }
                                    }
                                }
                                Text("This is the row you are currently on.")
                                    .font(.system(size: 12))
                                    .foregroundColor(KnitTheme.taupe)
                            }
                        }

                        fieldCard {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeader(title: "Notes (optional)")
                                ZStack(alignment: .topLeading) {
                                    if notes.isEmpty {
                                        Text("Add any notes...")
                                            .font(.system(size: 14))
                                            .foregroundColor(KnitTheme.taupe.opacity(0.5))
                                    }
                                    TextEditor(text: $notes)
                                        .font(.system(size: 14))
                                        .foregroundColor(KnitTheme.brown)
                                        .frame(minHeight: 80)
                                        .scrollContentBackground(.hidden)
                                }
                            }
                        }

                        Button("Save") {
                            let section = RowSection(
                                name: name,
                                startRow: startRow,
                                endRow: endRow,
                                currentRow: normalizedCurrentRow,
                                notes: notes,
                                isCompleted: endRow.map { normalizedCurrentRow >= $0 } ?? false
                            )
                            project.rowSections.append(section)
                            onSave()
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.5)
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Add Row Section")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                startRow = nil
                endRow = nil
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(KnitTheme.rose)
                }
            }
        }
    }

    var normalizedCurrentRow: Int {
        let lowerClamped = max(startingCounter, startRow ?? 1)
        return min(lowerClamped, endRow ?? lowerClamped)
    }

    var startRowEnabled: Binding<Bool> {
        Binding(
            get: { startRow != nil },
            set: { enabled in
                if enabled {
                    let proposed = max(1, min(startingCounter, endRow ?? startingCounter))
                    startRow = proposed
                    startingCounter = max(startingCounter, proposed)
                } else {
                    startRow = nil
                }
            }
        )
    }

    var endRowEnabled: Binding<Bool> {
        Binding(
            get: { endRow != nil },
            set: { enabled in
                if enabled {
                    let proposed = max(startRow ?? 1, startingCounter)
                    endRow = proposed
                    startingCounter = min(startingCounter, proposed)
                } else {
                    endRow = nil
                }
            }
        )
    }

    func fieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .cardStyle()
    }

    func optionalBoundaryCard(
        title: String,
        isEnabled: Binding<Bool>,
        value: Int?,
        emptyText: String,
        onDecrease: @escaping () -> Void,
        onIncrease: @escaping () -> Void
    ) -> some View {
        fieldCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "\(title) (optional)")
                    Spacer()
                    Toggle("", isOn: isEnabled)
                        .labelsHidden()
                        .tint(KnitTheme.rose)
                }

                if let value {
                    HStack {
                        Text("\(value)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(KnitTheme.brown)
                        Spacer()
                        HStack(spacing: 12) {
                            CounterButton(systemName: "minus", action: onDecrease)
                            CounterButton(systemName: "plus", action: onIncrease)
                        }
                    }
                } else {
                    Text(emptyText)
                        .font(.system(size: 13))
                        .foregroundColor(KnitTheme.taupe)
                }
            }
        }
    }
}

// MARK: - Edit Row Section

struct EditRowSectionView: View {
    let section: RowSection
    @Binding var project: KnitProject
    @Environment(\.dismiss) var dismiss
    let onSave: () -> Void

    @State private var name: String
    @State private var startRow: Int?
    @State private var endRow: Int?
    @State private var currentRow: Int
    @State private var notes: String

    init(section: RowSection, project: Binding<KnitProject>, onSave: @escaping () -> Void) {
        self.section = section
        self._project = project
        self.onSave = onSave
        self._name = State(initialValue: section.name)
        self._startRow = State(initialValue: section.startRow)
        self._endRow = State(initialValue: section.endRow)
        self._currentRow = State(initialValue: section.currentRow)
        self._notes = State(initialValue: section.notes)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KnitTheme.cream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        fieldCard {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeader(title: "Section Name")
                                TextField("Name", text: $name)
                                    .font(.system(size: 15))
                                    .foregroundColor(KnitTheme.brown)
                            }
                        }

                        HStack(spacing: 12) {
                            optionalEditBoundaryCard(
                                title: "Start Row",
                                isEnabled: editStartRowEnabled,
                                value: startRow,
                                emptyText: "No lower boundary",
                                onDecrease: {
                                    guard let startRow, startRow > 1 else { return }
                                    self.startRow = startRow - 1
                                    currentRow = max(currentRow, self.startRow ?? 1)
                                },
                                onIncrease: {
                                    let next = (startRow ?? max(1, min(currentRow, endRow ?? currentRow))) + 1
                                    self.startRow = next
                                    currentRow = max(currentRow, next)
                                    if let endRow, endRow < next {
                                        self.endRow = next
                                    }
                                }
                            )

                            optionalEditBoundaryCard(
                                title: "End Row",
                                isEnabled: editEndRowEnabled,
                                value: endRow,
                                emptyText: "No upper boundary",
                                onDecrease: {
                                    guard let endRow else { return }
                                    let minimumEnd = startRow ?? 1
                                    guard endRow > minimumEnd else { return }
                                    let next = endRow - 1
                                    self.endRow = next
                                    currentRow = min(currentRow, next)
                                },
                                onIncrease: {
                                    self.endRow = (endRow ?? max(startRow ?? 1, currentRow)) + 1
                                }
                            )
                        }

                        fieldCard {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeader(title: "Notes")
                                TextEditor(text: $notes)
                                    .font(.system(size: 14))
                                    .foregroundColor(KnitTheme.brown)
                                    .frame(minHeight: 80)
                                    .scrollContentBackground(.hidden)
                            }
                        }

                        Button("Save Changes") {
                            if let idx = project.rowSections.firstIndex(where: { $0.id == section.id }) {
                                let minimum = startRow ?? 1
                                let lowerClamped = max(currentRow, minimum)
                                let normalizedCurrentRow = min(lowerClamped, endRow ?? lowerClamped)

                                project.rowSections[idx].name = name
                                project.rowSections[idx].startRow = startRow
                                project.rowSections[idx].endRow = endRow
                                project.rowSections[idx].currentRow = normalizedCurrentRow
                                project.rowSections[idx].isCompleted = endRow.map { normalizedCurrentRow >= $0 } ?? false
                                project.rowSections[idx].notes = notes
                            }
                            onSave()
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Edit Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(KnitTheme.rose)
                }
            }
        }
    }

    var editStartRowEnabled: Binding<Bool> {
        Binding(
            get: { startRow != nil },
            set: { enabled in
                if enabled {
                    let proposed = max(1, min(currentRow, endRow ?? currentRow))
                    startRow = proposed
                    currentRow = max(currentRow, proposed)
                } else {
                    startRow = nil
                }
            }
        )
    }

    var editEndRowEnabled: Binding<Bool> {
        Binding(
            get: { endRow != nil },
            set: { enabled in
                if enabled {
                    let proposed = max(startRow ?? 1, currentRow)
                    endRow = proposed
                    currentRow = min(currentRow, proposed)
                } else {
                    endRow = nil
                }
            }
        )
    }

    func fieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .cardStyle()
    }

    func optionalEditBoundaryCard(
        title: String,
        isEnabled: Binding<Bool>,
        value: Int?,
        emptyText: String,
        onDecrease: @escaping () -> Void,
        onIncrease: @escaping () -> Void
    ) -> some View {
        fieldCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionHeader(title: title)
                    Spacer()
                    Toggle("", isOn: isEnabled)
                        .labelsHidden()
                        .tint(KnitTheme.rose)
                }

                if let value {
                    HStack {
                        Text("\(value)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(KnitTheme.brown)
                        Spacer()
                        VStack(spacing: 4) {
                            CounterButton(systemName: "plus", action: onIncrease)
                            CounterButton(systemName: "minus", action: onDecrease)
                        }
                    }
                } else {
                    Text(emptyText)
                        .font(.system(size: 13))
                        .foregroundColor(KnitTheme.taupe)
                }
            }
        }
    }
}
