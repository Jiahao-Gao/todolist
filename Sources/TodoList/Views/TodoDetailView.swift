import SwiftUI
import TodoCore

struct TodoDetailView: View {
    private let notesEditorHeight: CGFloat = 220

    @Binding var todo: TodoItem
    let canAddSubtasks: Bool
    let addSubtaskAction: () -> Void
    let selectTodoAction: (TodoItem.ID) -> Void
    @AppStorage(AppTypography.fontNameStorageKey) private var appFontName = AppTypography.defaultFontName

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $todo.title, prompt: Text("Todo title"))
                    .font(AppTypography.titleField(appFontName))

                Toggle("Completed", isOn: $todo.isCompleted)
            }

            Section("Schedule") {
                Toggle("Due Date", isOn: hasDueDate)

                if todo.dueDate != nil {
                    DatePicker(
                        "Due",
                        selection: dueDate,
                        displayedComponents: [.date]
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
        .formStyle(.grouped)
        .navigationTitle(todo.title.isEmpty ? "Todo" : todo.title)
    }

    private var hasDueDate: Binding<Bool> {
        Binding {
            todo.dueDate != nil
        } set: { hasDate in
            todo.dueDate = hasDate ? todo.dueDate ?? Date() : nil
        }
    }

    private var dueDate: Binding<Date> {
        Binding {
            todo.dueDate ?? Date()
        } set: { newDate in
            todo.dueDate = newDate
        }
    }

    private func deleteSubtask(id: TodoItem.ID) {
        todo.subtasks.removeAll { $0.id == id }
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

            if let dueDate = subtask.dueDate {
                Text(dueDate, style: .date)
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

    private func toggleCompletion() {
        subtask.isCompleted.toggle()
    }
}
