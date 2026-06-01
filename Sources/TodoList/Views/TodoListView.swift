import AppKit
import SwiftUI
import TodoCore
import UniformTypeIdentifiers

struct TodoListView: View {
    let title: String
    let items: [TodoItem]
    @Binding var selection: TodoItem.ID?
    let addAction: () -> Void
    let deleteAction: (Set<TodoItem.ID>) -> Void
    let toggleAction: (TodoItem.ID) -> Void
    let addSubtaskAction: (TodoItem.ID) -> Void
    let isReorderingEnabled: Bool
    let moveBeforeAction: (TodoItem.ID, TodoItem.ID) -> Void
    let moveAfterAction: (TodoItem.ID, TodoItem.ID) -> Void
    let moveAsSubtaskAction: (TodoItem.ID, TodoItem.ID) -> Void
    let moveToEndAsMainAction: (TodoItem.ID) -> Void
    @State private var collapsedTodoIDs: Set<TodoItem.ID> = []
    @State private var draggingTodoID: TodoItem.ID?
    @State private var dropPreview: TodoDropPreview?
    private let mainBorderGap: CGFloat = 6
    private let subtaskGap: CGFloat = 4
    private let rowHorizontalPadding: CGFloat = 10
    private let subtaskIndent: CGFloat = 50

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("No Todos", systemImage: "checklist")
                } description: {
                    Text("Create a todo or adjust the current filter.")
                } actions: {
                    Button(action: addAction) {
                        Label("New Todo", systemImage: "plus")
                    }
                }
            } else {
                List {
                    ForEach(visibleRows) { row in
                        switch row {
                        case let .main(item, isFirstGroup):
                            mainRow(for: item, isFirstGroup: isFirstGroup)
                        case let .subtask(_, subtask, isLastInGroup):
                            subtaskRow(
                                for: subtask,
                                isLastInGroup: isLastInGroup
                            )
                        }
                    }
                    .onDelete { indexSet in
                        let ids = Set(indexSet.map { visibleRows[$0].todoID })
                        deleteAction(ids)
                    }

                    if isReorderingEnabled {
                        listEndDropRow
                    }
                }
                .background(EmptyListClickDeselector(selection: $selection))
            }
        }
        .navigationTitle(title)
    }

    @ViewBuilder
    private func mainRow(for item: TodoItem, isFirstGroup: Bool) -> some View {
        reorderableRow(todoID: item.id, dropTarget: .main(item.id)) {
            VStack(spacing: 0) {
                if isFirstGroup {
                    mainGroupSeparator
                }

                deselectGap(height: mainBorderGap)

                HStack(spacing: 4) {
                    Button {
                        toggleExpansion(for: item.id)
                    } label: {
                        Image(systemName: isExpanded(item) ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .frame(width: 14)
                            .opacity(item.subtasks.isEmpty ? 0 : 1)
                            .foregroundStyle(selection == item.id ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(item.subtasks.isEmpty)
                    .help(isExpanded(item) ? "Hide Subtasks" : "Show Subtasks")

                    TodoRowView(
                        todo: item,
                        isSelected: selection == item.id,
                        toggleAction: {
                            toggleAction(item.id)
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selection = item.id
                    }
                }
                .padding(.horizontal, rowHorizontalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    if selection == item.id {
                        rowSelectionBackground
                    }
                }

                if item.subtasks.isEmpty || !isExpanded(item) {
                    deselectGap(height: mainBorderGap)

                    mainGroupSeparator
                }
            }
        }
        .contextMenu {
            contextMenu(for: item, canAddSubtask: true)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
    }

    private func subtaskRow(
        for subtask: TodoItem,
        isLastInGroup: Bool
    ) -> some View {
        reorderableRow(todoID: subtask.id, dropTarget: .subtask(subtask.id)) {
            VStack(spacing: 0) {
                deselectGap(height: subtaskGap)

                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: subtaskIndent)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selection = nil
                        }

                    TodoRowView(
                        todo: subtask,
                        isSubtask: true,
                        isSelected: selection == subtask.id,
                        toggleAction: {
                            toggleAction(subtask.id)
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        if selection == subtask.id {
                            rowSelectionBackground
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selection = subtask.id
                    }
                }
                .padding(.horizontal, rowHorizontalPadding)

                if isLastInGroup {
                    deselectGap(height: mainBorderGap)

                    mainGroupSeparator
                }
            }
        }
        .contextMenu {
            contextMenu(for: subtask, canAddSubtask: false)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
    }

    private var listEndDropRow: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: mainBorderGap + 5)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                if dropPreview == .listEnd {
                    insertionLine
                }
            }
            .onTapGesture {
                selection = nil
            }
            .onDrop(
                of: [.plainText],
                delegate: TodoListEndDropDelegate(
                    draggingTodoID: $draggingTodoID,
                    dropPreview: $dropPreview,
                    moveToEndAsMainAction: moveToEndAsMainAction
                )
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func reorderableRow<Content: View>(
        todoID: TodoItem.ID,
        dropTarget: TodoDropTarget,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if isReorderingEnabled {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .opacity(draggingTodoID == todoID ? 0.55 : 1)
                .onDrag {
                    draggingTodoID = todoID
                    return NSItemProvider(object: todoID.uuidString as NSString)
                }
                .onDrop(
                    of: [.plainText],
                    delegate: TodoRowDropDelegate(
                        target: dropTarget,
                        draggingTodoID: $draggingTodoID,
                        dropPreview: $dropPreview,
                        moveBeforeAction: moveBeforeAction,
                        moveAfterAction: moveAfterAction,
                        moveAsSubtaskAction: moveAsSubtaskAction,
                        expandParentAction: { parentID in
                            collapsedTodoIDs.remove(parentID)
                        }
                    )
                )
                .overlay {
                    if dropPreview == .row(targetID: dropTarget.todoID, placement: .inside) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.gray.opacity(0.08))
                            .overlay {
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.gray.opacity(0.65), lineWidth: 3)
                            }
                    }
                }
                .overlay(alignment: .top) {
                    if dropPreview == .row(targetID: dropTarget.todoID, placement: .before) {
                        insertionLine
                    }
                }
                .overlay(alignment: .bottom) {
                    if dropPreview == .row(targetID: dropTarget.todoID, placement: .after) {
                        insertionLine
                    }
                }
        } else {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private func contextMenu(for item: TodoItem, canAddSubtask: Bool) -> some View {
        Button(item.isCompleted ? "Mark Incomplete" : "Mark Complete") {
            toggleAction(item.id)
        }

        if canAddSubtask {
            Button("Add Subtask") {
                addSubtaskAction(item.id)
            }
        }

        Button("Delete", role: .destructive) {
            deleteAction([item.id])
        }
    }

    private var visibleRows: [TodoListRow] {
        items.enumerated().flatMap { itemIndex, item in
            var rows: [TodoListRow] = [.main(item, isFirstGroup: itemIndex == 0)]

            if !item.subtasks.isEmpty, isExpanded(item) {
                rows.append(
                    contentsOf: item.subtasks.enumerated().map { index, subtask in
                        .subtask(
                            parentID: item.id,
                            item: subtask,
                            isLastInGroup: index == item.subtasks.count - 1
                        )
                    }
                )
            }

            return rows
        }
    }

    private func isExpanded(_ item: TodoItem) -> Bool {
        !collapsedTodoIDs.contains(item.id)
    }

    private func toggleExpansion(for id: TodoItem.ID) {
        if collapsedTodoIDs.contains(id) {
            collapsedTodoIDs.remove(id)
        } else {
            collapsedTodoIDs.insert(id)
        }
    }

    private var insertionLine: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.gray.opacity(0.75))
            .frame(height: 5)
            .padding(.leading, 18)
            .padding(.trailing, 8)
    }

    private var rowSelectionBackground: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.accentColor.opacity(0.9))
    }

    private func deselectGap(height: CGFloat) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .contentShape(Rectangle())
            .onTapGesture {
                selection = nil
            }
    }

    private var mainGroupSeparator: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.36))
            .frame(height: 1.5)
            .padding(.horizontal, rowHorizontalPadding)
            .contentShape(Rectangle())
            .onTapGesture {
                selection = nil
            }
    }
}

private enum TodoListRow: Identifiable {
    case main(TodoItem, isFirstGroup: Bool)
    case subtask(parentID: TodoItem.ID, item: TodoItem, isLastInGroup: Bool)

    var id: String {
        switch self {
        case let .main(item, _):
            "main-\(item.id.uuidString)"
        case let .subtask(parentID, item, _):
            "subtask-\(parentID.uuidString)-\(item.id.uuidString)"
        }
    }

    var todoID: TodoItem.ID {
        switch self {
        case let .main(item, _):
            item.id
        case let .subtask(_, item, _):
            item.id
        }
    }
}

private enum TodoDropTarget: Equatable {
    case main(TodoItem.ID)
    case subtask(TodoItem.ID)

    var todoID: TodoItem.ID {
        switch self {
        case let .main(id), let .subtask(id):
            id
        }
    }
}

private enum TodoDropPlacement: Equatable {
    case before
    case inside
    case after
}

private enum TodoDropPreview: Equatable {
    case row(targetID: TodoItem.ID, placement: TodoDropPlacement)
    case listEnd
}

private struct TodoRowDropDelegate: DropDelegate {
    private let topReorderThreshold: CGFloat = 10
    private let bottomReorderThreshold: CGFloat = 30
    private let subtaskMidpoint: CGFloat = 18

    let target: TodoDropTarget
    @Binding var draggingTodoID: TodoItem.ID?
    @Binding var dropPreview: TodoDropPreview?
    let moveBeforeAction: (TodoItem.ID, TodoItem.ID) -> Void
    let moveAfterAction: (TodoItem.ID, TodoItem.ID) -> Void
    let moveAsSubtaskAction: (TodoItem.ID, TodoItem.ID) -> Void
    let expandParentAction: (TodoItem.ID) -> Void

    func dropEntered(info: DropInfo) {
        updatePreview(for: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updatePreview(for: info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        clearPreview()
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingTodoID, draggingTodoID != target.todoID else {
            self.draggingTodoID = nil
            clearPreview()
            return false
        }

        switch (target, placement(for: info)) {
        case let (.main(targetID), .before):
            moveBeforeAction(draggingTodoID, targetID)
        case let (.main(targetID), .after):
            moveAfterAction(draggingTodoID, targetID)
        case let (.main(targetID), .inside):
            moveAsSubtaskAction(draggingTodoID, targetID)
            expandParentAction(targetID)
        case let (.subtask(targetID), .before):
            moveBeforeAction(draggingTodoID, targetID)
        case let (.subtask(targetID), .after), let (.subtask(targetID), .inside):
            moveAfterAction(draggingTodoID, targetID)
        }

        self.draggingTodoID = nil
        clearPreview()
        return true
    }

    private func updatePreview(for info: DropInfo) {
        guard let draggingTodoID, draggingTodoID != target.todoID else {
            clearPreview()
            return
        }

        dropPreview = .row(targetID: target.todoID, placement: placement(for: info))
    }

    private func placement(for info: DropInfo) -> TodoDropPlacement {
        switch target {
        case .main:
            if info.location.y <= topReorderThreshold {
                return .before
            } else if info.location.y >= bottomReorderThreshold {
                return .after
            } else {
                return .inside
            }
        case .subtask:
            if info.location.y > subtaskMidpoint {
                return .after
            } else {
                return .before
            }
        }
    }

    private func clearPreview() {
        if case let .row(targetID, _) = dropPreview, targetID == target.todoID {
            dropPreview = nil
        }
    }
}

private struct TodoListEndDropDelegate: DropDelegate {
    @Binding var draggingTodoID: TodoItem.ID?
    @Binding var dropPreview: TodoDropPreview?
    let moveToEndAsMainAction: (TodoItem.ID) -> Void

    func dropEntered(info: DropInfo) {
        updatePreview()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updatePreview()
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        clearPreview()
    }

    func performDrop(info: DropInfo) -> Bool {
        guard dropPreview == .listEnd, let draggingTodoID else {
            clearPreview()
            return false
        }

        moveToEndAsMainAction(draggingTodoID)
        self.draggingTodoID = nil
        clearPreview()
        return true
    }

    private func updatePreview() {
        guard draggingTodoID != nil else {
            clearPreview()
            return
        }

        dropPreview = .listEnd
    }

    private func clearPreview() {
        if dropPreview == .listEnd {
            dropPreview = nil
        }
    }
}

private struct EmptyListClickDeselector: NSViewRepresentable {
    @Binding var selection: TodoItem.ID?

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.view = view
        context.coordinator.startMonitoring()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.selection = $selection
        context.coordinator.view = nsView
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }

    final class Coordinator {
        var selection: Binding<TodoItem.ID?>
        weak var view: NSView?
        private var eventMonitor: Any?

        init(selection: Binding<TodoItem.ID?>) {
            self.selection = selection
        }

        func startMonitoring() {
            guard eventMonitor == nil else {
                return
            }

            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.clearSelectionIfNeeded(for: event)
                return event
            }
        }

        func stopMonitoring() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
                self.eventMonitor = nil
            }
        }

        private func clearSelectionIfNeeded(for event: NSEvent) {
            guard let view,
                  let window = view.window,
                  event.window === window,
                  let boundsView = view.enclosingScrollView ?? view.superview else {
                return
            }

            let pointInBounds = boundsView.convert(event.locationInWindow, from: nil)

            guard boundsView.bounds.contains(pointInBounds),
                  let contentView = window.contentView,
                  let hitView = contentView.hitTest(contentView.convert(event.locationInWindow, from: nil)),
                  !hitView.isInListRow else {
                return
            }

            selection.wrappedValue = nil
        }
    }
}

private extension NSView {
    var isInListRow: Bool {
        var currentView: NSView? = self

        while let view = currentView {
            let typeName = String(describing: type(of: view))

            if typeName.contains("NSTableRowView") || typeName.contains("NSOutlineViewRowView") {
                return true
            }

            currentView = view.superview
        }

        return false
    }
}
