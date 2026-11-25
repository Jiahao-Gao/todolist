import SwiftUI
import TodoCore

struct ContentView: View {
    @ObservedObject var store: TodoStore

    @SceneStorage("selectedSidebarItem") private var selectedSidebarItemRawValue = TodoSidebarSelection.filter(.all).storageValue
    @SceneStorage("selectedTodoID") private var selectedTodoIDRawValue: String?
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, selection: selectedSidebarSelection)
        } content: {
            TodoListView(
                title: currentTitle,
                items: filteredItems,
                store: store,
                selection: selectedTodoID,
                addAction: addTodo,
                deleteAction: deleteTodos,
                clearTrashAction: clearTrash,
                recoverTrashAction: recoverTrash,
                toggleAction: toggleTodoFromList(id:),
                addSubtaskAction: addSubtask(to:),
                isTrashMode: currentSidebarSelection == .trash,
                isReorderingEnabled: currentSidebarSelection == .filter(.all),
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
                    tags: store.tags,
                    parentTodo: selectedParentTodo,
                    recurrenceSourceTodo: selectedRecurrenceSourceTodo,
                    isEditable: currentSidebarSelection != .trash,
                    canAddSubtasks: selectedTodoCanAddSubtasks,
                    canEditTag: selectedTodoCanEditTag,
                    canConfigureRecurrence: selectedTodoCanConfigureRecurrence,
                    addSubtaskAction: addSubtaskToSelectedTodo,
                    selectTodoAction: selectTodo(id:),
                    selectParentAction: selectParentTodo,
                    selectRecurrenceSourceAction: selectRecurrenceSourceTodo
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

                Button(action: sortAllTodosByDate) {
                    Label("Sort Todos", systemImage: "arrow.up.arrow.down")
                }
                .help(currentSidebarSelection == .filter(.all) ? "Sort Todos by Date" : "Sort is available in All")
                .disabled(currentSidebarSelection != .filter(.all))

                Button(role: .destructive, action: deleteSelectedTodo) {
                    Label("Delete Todo", systemImage: "trash")
                }
                .help(currentSidebarSelection == .trash ? "Clear Todo" : "Delete Todo")
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

    private var currentSidebarSelection: TodoSidebarSelection {
        TodoSidebarSelection(storageValue: selectedSidebarItemRawValue)
    }

    private var filteredItems: [TodoItem] {
        switch currentSidebarSelection {
        case let .filter(filter):
            store.filteredItems(for: filter, searchText: searchText)
        case let .tag(tagID):
            store.filteredItems(forTag: tagID, searchText: searchText)
        case .trash:
            store.filteredTrashItems(searchText: searchText)
        }
    }

    private var currentTitle: String {
        switch currentSidebarSelection {
        case let .filter(filter):
            filter.title
        case let .tag(tagID):
            store.tag(id: tagID)?.name ?? "Tag"
        case .trash:
            "Trash"
        }
    }

    private var selectedSidebarSelection: Binding<TodoSidebarSelection> {
        Binding {
            currentSidebarSelection
        } set: { newValue in
            selectedSidebarItemRawValue = newValue.storageValue
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
        guard let id = selectedTodoID.wrappedValue else {
            return nil
        }

        if currentSidebarSelection == .trash {
            guard store.trashTodo(id: id) != nil else {
                return nil
            }

            return Binding {
                store.trashTodo(id: id) ?? TodoItem(title: "")
            } set: { _ in }
        }

        guard store.todo(id: id) != nil else {
            return nil
        }

        return Binding {
            store.todo(id: id) ?? TodoItem(title: "")
        } set: { updatedItem in
            store.update(updatedItem)

            if store.isRecurrentEvent(id: updatedItem.id) {
                selectedSidebarItemRawValue = TodoSidebarSelection.filter(.recurrent).storageValue
            } else if currentSidebarSelection == .filter(.recurrent) {
                selectedSidebarItemRawValue = TodoSidebarSelection.filter(.all).storageValue
            }
        }
    }

    private var selectedTodoCanAddSubtasks: Bool {
        guard currentSidebarSelection != .trash else {
            return false
        }

        guard let id = selectedTodoID.wrappedValue else {
            return false
        }

        return store.isMainTodo(id: id)
    }

    private var selectedTodoCanEditTag: Bool {
        guard currentSidebarSelection != .trash else {
            return false
        }

        guard let id = selectedTodoID.wrappedValue else {
            return false
        }

        return store.isMainTodo(id: id)
    }

    private var selectedTodoCanConfigureRecurrence: Bool {
        guard currentSidebarSelection != .trash else {
            return false
        }

        guard let id = selectedTodoID.wrappedValue,
              store.isMainTodo(id: id),
              store.todo(id: id)?.recurrenceSourceID == nil else {
            return false
        }

        return true
    }

    private var selectedParentTodo: TodoItem? {
        guard currentSidebarSelection != .trash else {
            return nil
        }

        guard let id = selectedTodoID.wrappedValue else {
            return nil
        }

        return store.parentTodo(for: id)
    }

    private var selectedRecurrenceSourceTodo: TodoItem? {
        guard currentSidebarSelection != .trash else {
            return nil
        }

        guard let todo = selectedTodo?.wrappedValue else {
            return nil
        }

        return store.recurrenceSource(for: todo)
    }

    private func addTodo() {
        let todo = store.addTodo()
        selectedSidebarItemRawValue = TodoSidebarSelection.filter(.all).storageValue
        selectedTodoID.wrappedValue = todo.id
    }

    private func deleteTodos(_ ids: Set<TodoItem.ID>) {
        if currentSidebarSelection == .trash {
            store.clearTrash(ids: ids)
        } else {
            store.delete(ids: ids)
        }

        if selectedTodo == nil {
            selectedTodoID.wrappedValue = nil
        }
    }

    private func clearTrash(_ ids: Set<TodoItem.ID>) {
        store.clearTrash(ids: ids)

        if selectedTodo == nil {
            selectedTodoID.wrappedValue = nil
        }
    }

    private func recoverTrash(_ ids: Set<TodoItem.ID>) {
        store.recoverTrash(ids: ids)

        if selectedTodo == nil {
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
        guard currentSidebarSelection != .trash else {
            return
        }

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

    private func sortAllTodosByDate() {
        guard currentSidebarSelection == .filter(.all) else {
            return
        }

        store.sortAllByDate()
    }

    private func addSubtaskToSelectedTodo() {
        guard currentSidebarSelection != .trash else {
            return
        }

        guard let selectedID = selectedTodoID.wrappedValue else {
            return
        }

        addSubtask(to: selectedID)
    }

    private func selectTodo(id: TodoItem.ID) {
        selectedTodoID.wrappedValue = id
    }

    private func selectParentTodo() {
        guard let parent = selectedParentTodo else {
            return
        }

        selectedSidebarItemRawValue = TodoSidebarSelection.filter(.all).storageValue
        selectedTodoID.wrappedValue = parent.id
    }

    private func selectRecurrenceSourceTodo() {
        guard let recurrenceSource = selectedRecurrenceSourceTodo else {
            return
        }

        selectedSidebarItemRawValue = TodoSidebarSelection.filter(.recurrent).storageValue
        selectedTodoID.wrappedValue = recurrenceSource.id
    }

    private func addSubtask(to parentID: TodoItem.ID) {
        guard currentSidebarSelection != .trash else {
            return
        }

        guard let subtask = store.addSubtask(to: parentID) else {
            return
        }

        selectTodo(id: subtask.id)
    }

    private func toggleTodoFromList(id: TodoItem.ID) {
        guard currentSidebarSelection != .trash else {
            return
        }

        store.toggleCompletion(id: id)
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
