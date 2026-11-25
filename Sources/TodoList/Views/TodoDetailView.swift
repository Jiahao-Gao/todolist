import SwiftUI
import TodoCore

struct TodoDetailView: View {
    private let notesEditorHeight: CGFloat = 220

    @Binding var todo: TodoItem
    let tags: [TodoTag]
    let parentTodo: TodoItem?
    let recurrenceSourceTodo: TodoItem?
    let isEditable: Bool
    let canAddSubtasks: Bool
    let canEditTag: Bool
    let canConfigureRecurrence: Bool
    let addSubtaskAction: () -> Void
    let selectTodoAction: (TodoItem.ID) -> Void
    let selectParentAction: () -> Void
    let selectRecurrenceSourceAction: () -> Void
    @AppStorage(AppTypography.fontNameStorageKey) private var appFontName = AppTypography.defaultFontName
    @State private var titleDraft = ""

    var body: some View {
        Form {
            Section {
                TextField("Title", text: titleBinding, prompt: Text("Todo title"))
                    .font(AppTypography.titleField(appFontName))

                Toggle("Completed", isOn: $todo.isCompleted)

                HStack {
                    Text("Tag")

                    Spacer()

                    if canEditTag {
                        Picker("Tag", selection: tagSelection) {
                            Text("No Tag").tag("")

                            ForEach(tags) { tag in
                                Text(tag.name).tag(tag.id.uuidString)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 220, alignment: .trailing)
                    } else {
                        Text(inheritedTagName)
                            .foregroundStyle(.secondary)
                            .frame(width: 220, alignment: .trailing)
                    }
                }
            }

            Section("Schedule") {
                Toggle("Start Date", isOn: hasStartDate)

                if todo.dueDate != nil {
                    DatePicker(
                        "Start",
                        selection: startDate,
                        displayedComponents: [.date]
                    )

                    Toggle("End Date", isOn: hasEndDate)

                    if todo.endDate != nil {
                        DatePicker(
                            "End",
                            selection: endDate,
                            in: endDateRange,
                            displayedComponents: [.date]
                        )
                    }

                    if canConfigureRecurrence {
                        Toggle("Recurrent", isOn: hasRecurrence)

                        if todo.recurrenceRule != nil {
                            RecurrenceEditor(
                                rule: recurrenceRule,
                                startDate: todo.dueDate ?? Date()
                            )
                        }
                    }
                }
            }

            if let parentTodo {
                Section("Main Task") {
                    JumpRow(
                        title: parentTodo.title.isEmpty ? "Untitled Todo" : parentTodo.title,
                        action: selectParentAction
                    )
                }
            }

            if let recurrenceSourceTodo {
                Section("Recurrent Event") {
                    JumpRow(
                        title: recurrenceSourceTodo.title.isEmpty ? "Untitled Todo" : recurrenceSourceTodo.title,
                        action: selectRecurrenceSourceAction
                    )
                }
            }

            if canAddSubtasks {
                Section("Subtasks") {
                    ForEach($todo.subtasks) { $subtask in
                        SubtaskEditorRow(
                            subtask: $subtask,
                            selectAction: selectTodoAction,
                            deleteAction: deleteSubtask(id:)
                        )
                    }

                    Button(action: addSubtaskAction) {
                        Label("Add Subtask", systemImage: "plus")
                    }
                }
            }

            Section("Notes") {
                TextEditor(text: $todo.notes)
                    .font(AppTypography.notes(appFontName))
                    .frame(height: notesEditorHeight)
            }
        }
        .font(AppTypography.body(appFontName))
        .disabled(!isEditable)
        .formStyle(.grouped)
        .navigationTitle(todo.title.isEmpty ? "Todo" : todo.title)
        .onAppear {
            syncTitleDraft()
        }
        .onChange(of: todo.id) {
            syncTitleDraft()
        }
        .onChange(of: todo.title) {
            if titleDraft != todo.title {
                titleDraft = todo.title
            }
        }
    }

    private var titleBinding: Binding<String> {
        Binding {
            titleDraft
        } set: { newTitle in
            titleDraft = newTitle
            todo.title = newTitle
        }
    }

    private func syncTitleDraft() {
        titleDraft = todo.title
    }

    private var hasStartDate: Binding<Bool> {
        Binding {
            todo.dueDate != nil
        } set: { hasDate in
            if hasDate {
                todo.dueDate = todo.dueDate ?? Date()
            } else {
                todo.dueDate = nil
                todo.endDate = nil
                todo.recurrenceRule = nil
            }
        }
    }

    private var startDate: Binding<Date> {
        Binding {
            todo.dueDate ?? Date()
        } set: { newDate in
            todo.dueDate = newDate

            if let endDate = todo.endDate, endDate < newDate {
                todo.endDate = newDate
            }
        }
    }

    private var hasEndDate: Binding<Bool> {
        Binding {
            todo.endDate != nil
        } set: { hasDate in
            guard hasDate else {
                todo.endDate = nil
                return
            }

            let startDate = todo.dueDate ?? Date()
            todo.dueDate = startDate
            todo.endDate = max(todo.endDate ?? startDate, startDate)
            todo.recurrenceRule = nil
        }
    }

    private var endDate: Binding<Date> {
        Binding {
            todo.endDate ?? todo.dueDate ?? Date()
        } set: { newDate in
            let minimumDate = todo.dueDate ?? newDate
            todo.endDate = max(newDate, minimumDate)
        }
    }

    private var endDateRange: PartialRangeFrom<Date> {
        (todo.dueDate ?? Date())...
    }

    private var hasRecurrence: Binding<Bool> {
        Binding {
            todo.recurrenceRule != nil
        } set: { isRecurrent in
            guard isRecurrent else {
                todo.recurrenceRule = nil
                return
            }

            let startDate = todo.dueDate ?? Date()
            todo.dueDate = startDate
            todo.endDate = nil
            todo.recurrenceRule = RecurrenceRule(
                frequency: .daily,
                weekday: Calendar.current.component(.weekday, from: startDate),
                dayOfMonth: Calendar.current.component(.day, from: startDate)
            )
        }
    }

    private var recurrenceRule: Binding<RecurrenceRule> {
        Binding {
            todo.recurrenceRule ?? RecurrenceRule.daily()
        } set: { newRule in
            todo.endDate = nil
            todo.recurrenceRule = newRule
        }
    }

    private var tagSelection: Binding<String> {
        Binding {
            todo.tagID?.uuidString ?? ""
        } set: { newValue in
            todo.tagID = UUID(uuidString: newValue)
        }
    }

    private var inheritedTagName: String {
        guard let tagID = todo.tagID,
              let tag = tags.first(where: { $0.id == tagID }) else {
            return "No Tag"
        }

        return tag.name
    }

    private func deleteSubtask(id: TodoItem.ID) {
        todo.subtasks.removeAll { $0.id == id }
    }
}

private struct JumpRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .lineLimit(1)

            Spacer()

            Button(action: action) {
                Label("Open", systemImage: "arrow.right.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .help("Open")
        }
    }
}

private struct RecurrenceEditor: View {
    @Binding var rule: RecurrenceRule
    let startDate: Date

    var body: some View {
        Picker("Repeat", selection: frequency) {
            ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                Text(frequency.title).tag(frequency)
            }
        }

        switch rule.frequency {
        case .daily:
            EmptyView()
        case .weekly:
            Picker("On", selection: weekday) {
                ForEach(weekdayOptions, id: \.value) { option in
                    Text(option.title).tag(option.value)
                }
            }
        case .monthly:
            Stepper("On day \(dayOfMonth.wrappedValue)", value: dayOfMonth, in: 1...31)
        }

        Toggle("Limit Occurrences", isOn: hasOccurrenceLimit)

        if rule.occurrenceLimit != nil {
            Stepper("Occurrences: \(occurrenceLimit.wrappedValue)", value: occurrenceLimit, in: 1...999)
        }
    }

    private var frequency: Binding<RecurrenceFrequency> {
        Binding {
            rule.frequency
        } set: { newValue in
            rule.frequency = newValue
            rule.weekday = rule.weekday ?? Calendar.current.component(.weekday, from: startDate)
            rule.dayOfMonth = rule.dayOfMonth ?? Calendar.current.component(.day, from: startDate)
        }
    }

    private var weekday: Binding<Int> {
        Binding {
            rule.weekday ?? Calendar.current.component(.weekday, from: startDate)
        } set: { newValue in
            rule.weekday = newValue
        }
    }

    private var dayOfMonth: Binding<Int> {
        Binding {
            rule.dayOfMonth ?? Calendar.current.component(.day, from: startDate)
        } set: { newValue in
            rule.dayOfMonth = newValue
        }
    }

    private var hasOccurrenceLimit: Binding<Bool> {
        Binding {
            rule.occurrenceLimit != nil
        } set: { isLimited in
            rule.occurrenceLimit = isLimited ? rule.occurrenceLimit ?? 3 : nil
        }
    }

    private var occurrenceLimit: Binding<Int> {
        Binding {
            rule.occurrenceLimit ?? 3
        } set: { newValue in
            rule.occurrenceLimit = newValue
        }
    }

    private var weekdayOptions: [(value: Int, title: String)] {
        let symbols = Calendar.current.weekdaySymbols

        return (1...7).map { weekday in
            (weekday, symbols[weekday - 1])
        }
    }
}

private struct SubtaskEditorRow: View {
    @Binding var subtask: TodoItem
    let selectAction: (TodoItem.ID) -> Void
    let deleteAction: (TodoItem.ID) -> Void
    @AppStorage(AppTypography.fontNameStorageKey) private var appFontName = AppTypography.defaultFontName

    var body: some View {
        HStack(spacing: 10) {
            Button(action: toggleCompletion) {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(subtask.isCompleted ? .green : .secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .help(subtask.isCompleted ? "Mark Incomplete" : "Mark Complete")

            Text(displayTitle)
                .font(AppTypography.body(appFontName))
                .strikethrough(subtask.isCompleted)
                .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                .lineLimit(1)

            Spacer(minLength: 12)

            if let scheduleText {
                Text(scheduleText)
                    .font(AppTypography.taskDate(appFontName))
                    .foregroundStyle(subtask.isOverdue() ? .red : .secondary)
                    .lineLimit(1)
            }

            Button {
                selectAction(subtask.id)
            } label: {
                Label("Edit Subtask", systemImage: "arrow.right.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .help("Edit Subtask")

            Button(role: .destructive) {
                deleteAction(subtask.id)
            } label: {
                Label("Delete Subtask", systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .help("Delete Subtask")
        }
        .font(AppTypography.body(appFontName))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayTitle: String {
        let title = subtask.title.trimmingCharacters(in: .whitespacesAndNewlines)

        return title.isEmpty ? "Untitled Subtask" : title
    }

    private var scheduleText: String? {
        guard let dueDate = subtask.dueDate else {
            return nil
        }

        let startText = dueDate.formatted(date: .abbreviated, time: .omitted)

        guard let endDate = subtask.endDate,
              !Calendar.current.isDate(endDate, inSameDayAs: dueDate) else {
            return startText
        }

        return "\(startText) - \(endDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private func toggleCompletion() {
        subtask.isCompleted.toggle()
    }
}
