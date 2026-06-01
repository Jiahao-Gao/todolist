import SwiftUI

struct TodoCommands {
    var newTodo: () -> Void
    var deleteSelected: () -> Void
    var toggleSelected: () -> Void
    var clearCompleted: () -> Void
    var canModifySelection: Bool
    var hasCompletedTodos: Bool
}

private struct TodoCommandsKey: FocusedValueKey {
    typealias Value = TodoCommands
}

extension FocusedValues {
    var todoCommands: TodoCommands? {
        get { self[TodoCommandsKey.self] }
        set { self[TodoCommandsKey.self] = newValue }
    }
}

struct TodoListCommands: Commands {
    @FocusedValue(\.todoCommands) private var commands

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Todo") {
                commands?.newTodo()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(commands == nil)
        }

        CommandMenu("Todo") {
            Button("Toggle Complete") {
                commands?.toggleSelected()
            }
            .keyboardShortcut("l", modifiers: .command)
            .disabled(commands?.canModifySelection != true)

            Button("Delete Todo") {
                commands?.deleteSelected()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(commands?.canModifySelection != true)

            Divider()

            Button("Clear Completed") {
                commands?.clearCompleted()
            }
            .disabled(commands?.hasCompletedTodos != true)
        }
    }
}
