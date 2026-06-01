import Combine
import Foundation

@MainActor
public final class TodoStore: ObservableObject {
    @Published public private(set) var items: [TodoItem] = [] {
        didSet {
            guard autosavesChanges else {
                return
            }

            persist()
        }
    }

    @Published public private(set) var lastErrorMessage: String?

    private let persistence: TodoPersistence
    private var autosavesChanges = false

    public init(
        persistence: TodoPersistence = .applicationSupport(),
        seedSamples: Bool = true
    ) {
        self.persistence = persistence
        load(seedSamples: seedSamples)
        autosavesChanges = true

        if seedSamples, !items.isEmpty {
            persist()
        }
    }

    @discardableResult
    public func addTodo(
        title: String = "New Todo",
        notes: String = "",
        dueDate: Date? = nil,
        endDate: Date? = nil
    ) -> TodoItem {
        let item = TodoItem(
            title: title,
            notes: notes,
            dueDate: dueDate,
            endDate: endDate
        )

        var updatedItems = items
        updatedItems.insert(item, at: 0)
        items = updatedItems.renumberedBySiblingOrder()

        return todo(id: item.id) ?? item
    }

    @discardableResult
    public func addSubtask(
        to parentID: TodoItem.ID,
        title: String = "New Subtask",
        notes: String = "",
        dueDate: Date? = nil,
        endDate: Date? = nil
    ) -> TodoItem? {
        var updatedItems = items

        guard let parentIndex = updatedItems.firstIndex(where: { $0.id == parentID }) else {
            return nil
        }

        var subtask = TodoItem(
            title: title,
            notes: notes,
            isCompleted: updatedItems[parentIndex].isCompleted,
            dueDate: dueDate ?? updatedItems[parentIndex].dueDate,
            endDate: endDate ?? updatedItems[parentIndex].endDate
        )

        if updatedItems[parentIndex].isCompleted {
            subtask.completeIncludingSubtasks()
        }

        updatedItems[parentIndex].subtasks.insert(subtask, at: 0)
        items = updatedItems.renumberedBySiblingOrder()

        return todo(id: subtask.id) ?? subtask
    }

    public func update(_ item: TodoItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = items[index].updated(with: item)
            return
        }

        for index in items.indices where items[index].updateSubtask(item) {
            return
        }
    }

    public func toggleCompletion(id: TodoItem.ID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].toggleCompletionIncludingSubtasksWhenCompleted()
            return
        }

        for index in items.indices where items[index].toggleSubtaskCompletion(id: id) {
            return
        }
    }

    public func delete(id: TodoItem.ID) {
        delete(ids: [id])
    }

    public func delete(ids: Set<TodoItem.ID>) {
        var updatedItems = items
        updatedItems.removeAll { ids.contains($0.id) }

        for index in updatedItems.indices {
            updatedItems[index].deleteSubtasks(ids: ids)
        }

        items = updatedItems.renumberedBySiblingOrder()
    }

    public func clearCompleted() {
        var updatedItems = items
        updatedItems.removeAll { $0.isCompleted }

        for index in updatedItems.indices {
            updatedItems[index].removeCompletedSubtasks()
        }

        items = updatedItems.renumberedBySiblingOrder()
    }

    public func moveTodo(id: TodoItem.ID, before targetID: TodoItem.ID) {
        moveTodo(id: id, relativeTo: targetID, placement: .before)
    }

    public func moveTodo(id: TodoItem.ID, after targetID: TodoItem.ID) {
        moveTodo(id: id, relativeTo: targetID, placement: .after)
    }

    public func moveTodo(id: TodoItem.ID, asSubtaskOf parentID: TodoItem.ID) {
        guard id != parentID,
              todo(id: id)?.containsTodo(id: parentID) != true,
              let movedItem = removeTodo(id: id) else {
            return
        }

        if insertSubtask(movedItem, intoParent: parentID) {
            renumberItemOrders()
            return
        }

        items.append(movedItem)
        renumberItemOrders()
    }

    public func moveTodoToEndAsMain(id: TodoItem.ID) {
        guard let movedItem = removeTodo(id: id) else {
            return
        }

        items.append(movedItem)
        renumberItemOrders()
    }

    public func todo(id: TodoItem.ID) -> TodoItem? {
        for item in items {
            if let match = item.todo(id: id) {
                return match
            }
        }

        return nil
    }

    public func isMainTodo(id: TodoItem.ID) -> Bool {
        items.contains { $0.id == id }
    }

    public func filteredItems(
        for filter: TodoFilter,
        searchText: String = "",
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [TodoItem] {
        items
            .sortedByStoredOrder()
            .compactMap { $0.filtered(for: filter, referenceDate: referenceDate, calendar: calendar) }
            .filter { $0.matches(searchText: searchText) }
    }

    public func sortAllByDate(calendar: Calendar = .current) {
        items = items
            .sortedByStoredOrder()
            .sortedBySchedule(calendar: calendar)
            .renumberedBySiblingOrder()
    }

    public func count(
        for filter: TodoFilter,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        filteredItems(for: filter, referenceDate: referenceDate, calendar: calendar).count
    }

    private func load(seedSamples: Bool) {
        do {
            let loadedItems = try persistence.load()
            items = (loadedItems.isEmpty && seedSamples ? Self.sampleItems() : loadedItems)
                .sortedByStoredOrder()
                .renumberedBySiblingOrder()
            lastErrorMessage = nil
        } catch {
            items = (seedSamples ? Self.sampleItems() : [])
                .renumberedBySiblingOrder()
            lastErrorMessage = "Could not load todos: \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            try persistence.save(items)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Could not save todos: \(error.localizedDescription)"
        }
    }

    private enum MovePlacement {
        case before
        case after
    }

    private func moveTodo(id: TodoItem.ID, relativeTo targetID: TodoItem.ID, placement: MovePlacement) {
        guard id != targetID,
              todo(id: id)?.containsTodo(id: targetID) != true,
              let movedItem = removeTodo(id: id) else {
            return
        }

        let didInsert: Bool

        switch placement {
        case .before:
            didInsert = insert(movedItem, before: targetID)
        case .after:
            didInsert = insert(movedItem, after: targetID)
        }

        if !didInsert {
            items.append(movedItem)
        }

        renumberItemOrders()
    }

    private func renumberItemOrders() {
        items = items.renumberedBySiblingOrder()
    }

    private func removeTodo(id: TodoItem.ID) -> TodoItem? {
        if let index = items.firstIndex(where: { $0.id == id }) {
            return items.remove(at: index)
        }

        for index in items.indices {
            if let removedItem = items[index].removeSubtask(id: id) {
                return removedItem
            }
        }

        return nil
    }

    private func insert(_ item: TodoItem, before targetID: TodoItem.ID) -> Bool {
        if let index = items.firstIndex(where: { $0.id == targetID }) {
            items.insert(item, at: index)
            return true
        }

        for index in items.indices where items[index].insertSubtask(item, before: targetID) {
            return true
        }

        return false
    }

    private func insert(_ item: TodoItem, after targetID: TodoItem.ID) -> Bool {
        if let index = items.firstIndex(where: { $0.id == targetID }) {
            items.insert(item, at: items.index(after: index))
            return true
        }

        for index in items.indices where items[index].insertSubtask(item, after: targetID) {
            return true
        }

        return false
    }

    private func insertSubtask(_ item: TodoItem, intoParent parentID: TodoItem.ID) -> Bool {
        for index in items.indices {
            if items[index].id == parentID {
                var subtask = item

                if items[index].isCompleted {
                    subtask.completeIncludingSubtasks()
                }

                items[index].subtasks.append(subtask)
                return true
            }

            if items[index].insertSubtask(item, intoParent: parentID) {
                return true
            }
        }

        return false
    }

    private static func sampleItems() -> [TodoItem] {
        let calendar = Calendar.current
        let now = Date()

        return [
            TodoItem(
                title: "Sketch the first real project tasks",
                notes: "Replace these starter todos with the shape of your own project.",
                dueDate: now
            ),
            TodoItem(
                title: "Try the toolbar, menu commands, and search",
                notes: "Use Command-N for a new todo and Delete to remove a selected item.",
                dueDate: calendar.date(byAdding: .day, value: 1, to: now)
            ),
            TodoItem(
                title: "Customize this starter",
                notes: "Use this app as a base for your own workflow.",
                dueDate: nil
            )
        ]
    }
}

private extension TodoItem {
    func todo(id: TodoItem.ID) -> TodoItem? {
        if self.id == id {
            return self
        }

        for subtask in subtasks {
            if let match = subtask.todo(id: id) {
                return match
            }
        }

        return nil
    }

    func containsTodo(id: TodoItem.ID) -> Bool {
        todo(id: id) != nil
    }

    func updated(with replacement: TodoItem) -> TodoItem {
        var updatedItem = replacement

        if !isCompleted, updatedItem.isCompleted {
            updatedItem.completeIncludingSubtasks()
        }

        return updatedItem
    }

    mutating func updateSubtask(_ replacement: TodoItem) -> Bool {
        for index in subtasks.indices {
            if subtasks[index].id == replacement.id {
                subtasks[index] = subtasks[index].updated(with: replacement)
                return true
            }

            if subtasks[index].updateSubtask(replacement) {
                return true
            }
        }

        return false
    }

    mutating func toggleCompletionIncludingSubtasksWhenCompleted() {
        isCompleted.toggle()

        if isCompleted {
            completeIncludingSubtasks()
        }
    }

    mutating func toggleSubtaskCompletion(id: TodoItem.ID) -> Bool {
        for index in subtasks.indices {
            if subtasks[index].id == id {
                subtasks[index].toggleCompletionIncludingSubtasksWhenCompleted()
                return true
            }

            if subtasks[index].toggleSubtaskCompletion(id: id) {
                return true
            }
        }

        return false
    }

    mutating func completeIncludingSubtasks() {
        isCompleted = true

        for index in subtasks.indices {
            subtasks[index].completeIncludingSubtasks()
        }
    }

    mutating func deleteSubtasks(ids: Set<TodoItem.ID>) {
        subtasks.removeAll { ids.contains($0.id) }

        for index in subtasks.indices {
            subtasks[index].deleteSubtasks(ids: ids)
        }
    }

    mutating func removeCompletedSubtasks() {
        subtasks.removeAll { $0.isCompleted }

        for index in subtasks.indices {
            subtasks[index].removeCompletedSubtasks()
        }
    }

    mutating func removeSubtask(id: TodoItem.ID) -> TodoItem? {
        if let index = subtasks.firstIndex(where: { $0.id == id }) {
            return subtasks.remove(at: index)
        }

        for index in subtasks.indices {
            if let removedItem = subtasks[index].removeSubtask(id: id) {
                return removedItem
            }
        }

        return nil
    }

    mutating func insertSubtask(_ item: TodoItem, before targetID: TodoItem.ID) -> Bool {
        if let index = subtasks.firstIndex(where: { $0.id == targetID }) {
            subtasks.insert(item, at: index)
            return true
        }

        for index in subtasks.indices where subtasks[index].insertSubtask(item, before: targetID) {
            return true
        }

        return false
    }

    mutating func insertSubtask(_ item: TodoItem, after targetID: TodoItem.ID) -> Bool {
        if let index = subtasks.firstIndex(where: { $0.id == targetID }) {
            subtasks.insert(item, at: subtasks.index(after: index))
            return true
        }

        for index in subtasks.indices where subtasks[index].insertSubtask(item, after: targetID) {
            return true
        }

        return false
    }

    mutating func insertSubtask(_ item: TodoItem, intoParent parentID: TodoItem.ID) -> Bool {
        if id == parentID {
            var subtask = item

            if isCompleted {
                subtask.completeIncludingSubtasks()
            }

            subtasks.append(subtask)
            return true
        }

        for index in subtasks.indices where subtasks[index].insertSubtask(item, intoParent: parentID) {
            return true
        }

        return false
    }

    func filtered(
        for filter: TodoFilter,
        referenceDate: Date,
        calendar: Calendar
    ) -> TodoItem? {
        if filter.isDateCategory {
            return dateCategoryFiltered(for: filter, referenceDate: referenceDate, calendar: calendar)
        }

        guard filter.includes(self, referenceDate: referenceDate, calendar: calendar) else {
            return nil
        }

        return self
    }

    private func dateCategoryFiltered(
        for filter: TodoFilter,
        referenceDate: Date,
        calendar: Calendar
    ) -> TodoItem? {
        guard !isCompleted,
              filter.includes(self, referenceDate: referenceDate, calendar: calendar)
                || subtasks.contains(where: {
                    $0.hasDateCategoryMatch(for: filter, referenceDate: referenceDate, calendar: calendar)
                }) else {
            return nil
        }

        return self
    }

    private func hasDateCategoryMatch(
        for filter: TodoFilter,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        filter.includes(self, referenceDate: referenceDate, calendar: calendar)
            || subtasks.contains {
                $0.hasDateCategoryMatch(for: filter, referenceDate: referenceDate, calendar: calendar)
            }
    }
}

private extension TodoFilter {
    var isDateCategory: Bool {
        self == .today || self == .upcoming || self == .overdue
    }
}

private extension Array where Element == TodoItem {
    func sortedByStoredOrder() -> [TodoItem] {
        stableSorted { lhs, rhs in
            lhs.order < rhs.order
        }
        .map { item in
            var orderedItem = item
            orderedItem.subtasks = item.subtasks.sortedByStoredOrder()
            return orderedItem
        }
    }

    func sortedBySchedule(calendar: Calendar) -> [TodoItem] {
        map { item in
            var sortedItem = item
            sortedItem.subtasks = item.subtasks.sortedBySchedule(calendar: calendar)
            return sortedItem
        }
        .stableSorted { lhs, rhs in
            switch (lhs.effectiveScheduleSortDate(calendar: calendar), rhs.effectiveScheduleSortDate(calendar: calendar)) {
            case let (lhsDate?, rhsDate?):
                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                break
            }

            return false
        }
    }

    func renumberedBySiblingOrder() -> [TodoItem] {
        enumerated().map { index, item in
            var renumberedItem = item
            renumberedItem.order = index
            renumberedItem.subtasks = item.subtasks.renumberedBySiblingOrder()
            return renumberedItem
        }
    }

    private func stableSorted(
        by areInIncreasingOrder: (TodoItem, TodoItem) -> Bool
    ) -> [TodoItem] {
        enumerated()
            .sorted { lhs, rhs in
                if areInIncreasingOrder(lhs.element, rhs.element) {
                    return true
                }

                if areInIncreasingOrder(rhs.element, lhs.element) {
                    return false
                }

                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}

private extension TodoItem {
    func effectiveScheduleSortDate(calendar: Calendar) -> Date? {
        if let subtaskDate = subtasks.compactMap({ $0.earliestScheduleDate(calendar: calendar) }).min() {
            return subtaskDate
        }

        return dueDate.map { calendar.startOfDay(for: $0) }
    }

    func earliestScheduleDate(calendar: Calendar) -> Date? {
        let dates = [dueDate.map { calendar.startOfDay(for: $0) }]
            + subtasks.map { $0.earliestScheduleDate(calendar: calendar) }

        return dates.compactMap { $0 }.min()
    }
}
