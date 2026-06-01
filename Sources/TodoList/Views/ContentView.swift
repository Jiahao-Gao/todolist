import SwiftUI
import TodoCore

struct ContentView: View {
    @ObservedObject var store: TodoStore

    @SceneStorage("selectedFilter") private var selectedFilterRawValue = TodoFilter.all.rawValue
    @SceneStorage("selectedTodoID") private var selectedTodoIDRawValue: String?
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, selection: selectedFilter)
        } content: {
            TodoListView(
                title: currentFilter.title,
                items: filteredItems,
                selection: selectedTodoID,
                addAction: addTodo,
                deleteAction: deleteTodos,
                toggleAction: store.toggleCompletion(id:),
                addSubtaskAction: addSubtask(to:),
                isReorderingEnabled: currentFilter == .all,
                moveBeforeAction: moveTodoBefore(_:_:),
                moveAfterAction: moveTodoAfter(_:_:),
                moveAsSubtaskAction: moveTodoAsSubtask(_:_:),
                moveToEndAsMainAction: moveTodoToEndAsMain(_:)
            )
            .searchable(text: $searchText, placement: .toolbar, prompt: "Search Todos")
        } detail: {
            if let todo = selectedTodo {
                TodoDetailView(
                    todo: todo,
                    canAddSubtasks: selectedTodoCanAddSubtasks,
                    addSubtaskAction: addSubtaskToSelectedTodo,
                    selectTodoAction: selectTodo(id:)
                )
            } else {
                EmptyDetailView(addAction: addTodo)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: addTodo) {
                    Label("New Todo", systemImage: "plus")
                }
                .help("New Todo")

                Button(role: .destructive, action: deleteSelectedTodo) {
                    Label("Delete Todo", systemImage: "trash")
                }
                .help("Delete Todo")
                .disabled(selectedTodoID.wrappedValue == nil)
            }
        }
        .focusedValue(
            \.todoCommands,
            TodoCommands(
                newTodo: addTodo,
                deleteSelected: deleteSelectedTodo,
                toggleSelected: toggleSelectedTodo,
                clearCompleted: clearCompletedTodos,
                canModifySelection: selectedTodoID.wrappedValue != nil,
                hasCompletedTodos: store.count(for: .completed) > 0
            )
        )
    }

    private var currentFilter: TodoFilter {
        TodoFilter(rawValue: selectedFilterRawValue) ?? .all
    }

    private var filteredItems: [TodoItem] {
        store.filteredItems(for: currentFilter, searchText: searchText)
    }

    private var selectedFilter: Binding<TodoFilter> {
        Binding {
            currentFilter
        } set: { newValue in
            selectedFilterRawValue = newValue.rawValue
        }
    }

    private var selectedTodoID: Binding<TodoItem.ID?> {
        Binding {
            selectedTodoIDRawValue.flatMap(UUID.init(uuidString:))
        } set: { newValue in
            selectedTodoIDRawValue = newValue?.uuidString
        }
    }

    private var selectedTodo: Binding<TodoItem>? {
        guard let id = selectedTodoID.wrappedValue, store.todo(id: id) != nil else {
            return nil
        }

        return Binding {
            store.todo(id: id) ?? TodoItem(title: "")
        } set: { updatedItem in
            store.update(updatedItem)
        }
    }

    private var selectedTodoCanAddSubtasks: Bool {
        guard let id = selectedTodoID.wrappedValue else {
            return false
        }

        return store.isMainTodo(id: id)
    }

    private func addTodo() {
        let todo = store.addTodo()
        selectedFilterRawValue = TodoFilter.all.rawValue
        selectedTodoID.wrappedValue = todo.id
    }

    private func deleteTodos(_ ids: Set<TodoItem.ID>) {
        store.delete(ids: ids)

        if let selectedID = selectedTodoID.wrappedValue, store.todo(id: selectedID) == nil {
            selectedTodoID.wrappedValue = nil
        }
    }

    private func deleteSelectedTodo() {
        guard let selectedID = selectedTodoID.wrappedValue else {
            return
        }

        deleteTodos([selectedID])
    }

    private func toggleSelectedTodo() {
        guard let selectedID = selectedTodoID.wrappedValue else {
            return
        }

        store.toggleCompletion(id: selectedID)
    }

    private func clearCompletedTodos() {
        store.clearCompleted()

        if let selectedID = selectedTodoID.wrappedValue, store.todo(id: selectedID) == nil {
            selectedTodoID.wrappedValue = nil
        }
    }

    private func addSubtaskToSelectedTodo() {
        guard let selectedID = selectedTodoID.wrappedValue else {
            return
        }

        addSubtask(to: selectedID)
    }

    private func selectTodo(id: TodoItem.ID) {
        selectedTodoID.wrappedValue = id
    }

    private func addSubtask(to parentID: TodoItem.ID) {
        guard let subtask = store.addSubtask(to: parentID) else {
            return
        }

        selectTodo(id: subtask.id)
    }

    private func moveTodoBefore(_ todoID: TodoItem.ID, _ targetID: TodoItem.ID) {
        store.moveTodo(id: todoID, before: targetID)
        selectTodo(id: todoID)
    }

    private func moveTodoAfter(_ todoID: TodoItem.ID, _ targetID: TodoItem.ID) {
        store.moveTodo(id: todoID, after: targetID)
        selectTodo(id: todoID)
    }

    private func moveTodoAsSubtask(_ todoID: TodoItem.ID, _ parentID: TodoItem.ID) {
        store.moveTodo(id: todoID, asSubtaskOf: parentID)
        selectTodo(id: todoID)
    }

    private func moveTodoToEndAsMain(_ todoID: TodoItem.ID) {
        store.moveTodoToEndAsMain(id: todoID)
        selectTodo(id: todoID)
    }
}

private struct EmptyDetailView: View {
    let addAction: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Todo Selected", systemImage: "checklist")
        } description: {
            Text("Select a todo or create a new one.")
        } actions: {
            Button(action: addAction) {
                Label("New Todo", systemImage: "plus")
            }
        }
    }
}
