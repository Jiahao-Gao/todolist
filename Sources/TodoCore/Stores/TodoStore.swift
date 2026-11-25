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

    @Published public private(set) var recurrentEvents: [TodoItem] = [] {
        didSet {
            guard autosavesChanges else {
                return
            }

            persist()
        }
    }

    @Published public private(set) var tags: [TodoTag] = [] {
        didSet {
            guard autosavesChanges else {
                return
            }

            persist()
        }
    }

    @Published public private(set) var trashItems: [TodoItem] = [] {
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
        let didApplyLifecycle = applyLifecycle()
        let didGenerateRecurrences = generateDueRecurrences()
        autosavesChanges = true

        if didApplyLifecycle || didGenerateRecurrences || (seedSamples && !items.isEmpty) {
            persist()
        }
    }

    @discardableResult
    public func addTodo(
        title: String = "New Todo",
        notes: String = "",
        dueDate: Date? = nil,
        endDate: Date? = nil,
        tagID: TodoTag.ID? = nil
    ) -> TodoItem {
        let item = TodoItem(
            title: title,
            notes: notes,
            dueDate: dueDate,
            endDate: endDate,
            tagID: tagID
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
            endDate: endDate ?? updatedItems[parentIndex].endDate,
            tagID: updatedItems[parentIndex].tagID
        )

        if updatedItems[parentIndex].isCompleted {
            subtask.completeIncludingSubtasks(completionDate: Date())
        }

        updatedItems[parentIndex].subtasks.insert(subtask, at: 0)
        items = updatedItems.renumberedBySiblingOrder()

        return todo(id: subtask.id) ?? subtask
    }

    public func update(_ item: TodoItem) {
        let completionDate = Date()

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = items[index].updated(with: item)
            updatedItem.applyCompletionState(from: items[index], completionDate: completionDate)
            updatedItem.propagateTagToSubtasks()

            if updatedItem.recurrenceRule != nil {
                updatedItem.endDate = nil
                updatedItem.recurrenceSourceID = nil
                updatedItem.recurrenceOccurrenceDate = nil
                items.remove(at: index)
                recurrentEvents.insert(updatedItem, at: 0)
                recurrentEvents = recurrentEvents.renumberedBySiblingOrder()
                items = items.renumberedBySiblingOrder()
                return
            }

            items[index] = updatedItem
            return
        }

        if let index = recurrentEvents.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = recurrentEvents[index].updated(with: item)
            updatedItem.applyCompletionState(from: recurrentEvents[index], completionDate: completionDate)
            updatedItem.propagateTagToSubtasks()

            if updatedItem.recurrenceRule == nil {
                updatedItem.recurrenceSourceID = nil
                updatedItem.recurrenceOccurrenceDate = nil
                recurrentEvents.remove(at: index)
                items.insert(updatedItem, at: 0)
                recurrentEvents = recurrentEvents.renumberedBySiblingOrder()
                items = items.renumberedBySiblingOrder()
                return
            }

            updatedItem.endDate = nil
            recurrentEvents[index] = updatedItem
            return
        }

        for index in items.indices where items[index].updateSubtask(item, completionDate: completionDate) {
            return
        }

        for index in recurrentEvents.indices where recurrentEvents[index].updateSubtask(item, completionDate: completionDate) {
            return
        }
    }

    public func toggleCompletion(id: TodoItem.ID) {
        let completionDate = Date()

        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].toggleCompletionIncludingSubtasksWhenCompleted(completionDate: completionDate)
            return
        }

        if let index = recurrentEvents.firstIndex(where: { $0.id == id }) {
            recurrentEvents[index].toggleCompletionIncludingSubtasksWhenCompleted(completionDate: completionDate)
            return
        }

        for index in items.indices where items[index].toggleSubtaskCompletion(id: id, completionDate: completionDate) {
            return
        }

        for index in recurrentEvents.indices where recurrentEvents[index].toggleSubtaskCompletion(id: id, completionDate: completionDate) {
            return
        }
    }

    public func delete(id: TodoItem.ID) {
        delete(ids: [id])
    }

    public func delete(ids: Set<TodoItem.ID>) {
        moveToTrash(ids: ids)
    }

    public func moveToTrash(ids: Set<TodoItem.ID>, deletionDate: Date = Date()) {
        var movedItems: [TodoItem] = []

        for id in ids {
            guard let removedItem = removeTodoForTrash(id: id) else {
                continue
            }

            var trashItem = removedItem.item
            trashItem.prepareForTrash(
                origin: removedItem.origin,
                parentID: removedItem.parentID,
                deletionDate: deletionDate
            )
            movedItems.append(trashItem)
        }

        guard !movedItems.isEmpty else {
            return
        }

        items = items.renumberedBySiblingOrder()
        recurrentEvents = recurrentEvents.renumberedBySiblingOrder()
        trashItems = (movedItems + trashItems).renumberedBySiblingOrder()
    }

    public func clearCompleted() {
        moveToTrash(ids: completedTodoIDs())
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

        for event in recurrentEvents {
            if let match = event.todo(id: id) {
                return match
            }
        }

        return nil
    }

    public func trashTodo(id: TodoItem.ID) -> TodoItem? {
        for item in trashItems {
            if let match = item.todo(id: id) {
                return match
            }
        }

        return nil
    }

    public func isMainTodo(id: TodoItem.ID) -> Bool {
        items.contains { $0.id == id } || recurrentEvents.contains { $0.id == id }
    }

    public func isRecurrentEvent(id: TodoItem.ID) -> Bool {
        recurrentEvents.contains { $0.id == id }
    }

    public func parentTodo(for id: TodoItem.ID) -> TodoItem? {
        for item in items {
            if let parent = item.parentTodo(for: id) {
                return parent
            }
        }

        for event in recurrentEvents {
            if let parent = event.parentTodo(for: id) {
                return parent
            }
        }

        return nil
    }

    public func recurrenceSource(for item: TodoItem) -> TodoItem? {
        guard let recurrenceSourceID = item.recurrenceSourceID else {
            return nil
        }

        return recurrentEvents.first { $0.id == recurrenceSourceID }
    }

    public func tag(id: TodoTag.ID?) -> TodoTag? {
        guard let id else {
            return nil
        }

        return tags.first { $0.id == id }
    }

    public func effectiveTag(for item: TodoItem) -> TodoTag? {
        if let tag = tag(id: item.tagID) {
            return tag
        }

        return tag(id: parentTodo(for: item.id)?.tagID)
    }

    public func filteredItems(
        for filter: TodoFilter,
        searchText: String = "",
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [TodoItem] {
        let sourceItems = filter == .recurrent ? recurrentEvents : items

        return sourceItems
            .sortedByStoredOrder()
            .compactMap { $0.filtered(for: filter, referenceDate: referenceDate, calendar: calendar) }
            .filter { $0.matches(searchText: searchText) }
    }

    public func filteredItems(
        forTag tagID: TodoTag.ID,
        searchText: String = ""
    ) -> [TodoItem] {
        items
            .sortedByStoredOrder()
            .filter { $0.containsTag(id: tagID) }
            .filter { $0.matches(searchText: searchText) }
    }

    public func filteredTrashItems(searchText: String = "") -> [TodoItem] {
        trashItems
            .sortedByStoredOrder()
            .filter { $0.matches(searchText: searchText) }
    }

    public func sortAllByDate(calendar: Calendar = .current) {
        items = items
            .sortedByStoredOrder()
            .sortedBySchedule(calendar: calendar)
            .renumberedBySiblingOrder()
    }

    @discardableResult
    public func addTag(name: String? = nil) -> TodoTag {
        let tagName = name ?? nextTagName()
        let tag = TodoTag(
            name: tagName,
            color: TodoTagColor.allCases[tags.count % TodoTagColor.allCases.count]
        )

        var updatedTags = tags
        updatedTags.append(tag)
        tags = updatedTags.renumberedByTagOrder()

        return tags.first { $0.id == tag.id } ?? tag
    }

    public func renameTag(id: TodoTag.ID, name: String) {
        guard let index = tags.firstIndex(where: { $0.id == id }) else {
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tags[index].name = trimmedName.isEmpty ? tags[index].name : trimmedName
    }

    public func updateTagColor(id: TodoTag.ID, color: TodoTagColor) {
        guard let index = tags.firstIndex(where: { $0.id == id }) else {
            return
        }

        tags[index].color = color
    }

    public func deleteTag(id: TodoTag.ID) {
        tags.removeAll { $0.id == id }

        for index in items.indices {
            items[index].clearTag(id: id)
        }

        for index in recurrentEvents.indices {
            recurrentEvents[index].clearTag(id: id)
        }

        tags = tags.renumberedByTagOrder()
    }

    public func deleteTagAndTasks(id: TodoTag.ID) {
        let matchingIDs = todoIDsWithTag(id: id)
        moveToTrash(ids: matchingIDs)
        deleteTag(id: id)
    }

    public func count(
        for filter: TodoFilter,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        filteredItems(for: filter, referenceDate: referenceDate, calendar: calendar).count
    }

    public func count(forTag tagID: TodoTag.ID) -> Int {
        filteredItems(forTag: tagID).count
    }

    public func trashCount() -> Int {
        trashItems.count
    }

    public func clearTrash(ids: Set<TodoItem.ID>) {
        guard !ids.isEmpty else {
            return
        }

        trashItems.removeAll { ids.contains($0.id) }

        for index in trashItems.indices {
            trashItems[index].deleteSubtasks(ids: ids)
        }

        trashItems = trashItems.renumberedBySiblingOrder()
    }

    public func recoverTrash(ids: Set<TodoItem.ID>) {
        for id in ids {
            guard var recoveredItem = removeTrashTodo(id: id) else {
                continue
            }

            let origin = recoveredItem.trashOrigin ?? .active
            let parentID = recoveredItem.deletedParentID
            recoveredItem.restoreFromTrash()

            switch origin {
            case .active:
                recover(recoveredItem, parentID: parentID, intoRecurrentEvents: false)
            case .recurrent:
                recover(recoveredItem, parentID: parentID, intoRecurrentEvents: true)
            }
        }

        items = items.renumberedBySiblingOrder()
        recurrentEvents = recurrentEvents.renumberedBySiblingOrder()
        trashItems = trashItems.renumberedBySiblingOrder()
    }

    private func load(seedSamples: Bool) {
        do {
            let loadedSnapshot = try persistence.loadSnapshot()
            let snapshot = loadedSnapshot.isEmpty && seedSamples ? Self.defaultSeedSnapshot() : loadedSnapshot

            items = snapshot.items
                .sortedByStoredOrder()
                .renumberedBySiblingOrder()
            recurrentEvents = snapshot.recurrentEvents
                .sortedByStoredOrder()
                .renumberedBySiblingOrder()
            tags = snapshot.tags
                .sorted { $0.order < $1.order }
                .renumberedByTagOrder()
            trashItems = snapshot.trashItems
                .sortedByStoredOrder()
                .renumberedBySiblingOrder()
            lastErrorMessage = nil
        } catch {
            let snapshot = seedSamples ? Self.defaultSeedSnapshot() : TodoPersistenceSnapshot()
            items = snapshot.items
                .sortedByStoredOrder()
                .renumberedBySiblingOrder()
            recurrentEvents = snapshot.recurrentEvents
                .sortedByStoredOrder()
                .renumberedBySiblingOrder()
            tags = snapshot.tags
                .sorted { $0.order < $1.order }
                .renumberedByTagOrder()
            trashItems = snapshot.trashItems
                .sortedByStoredOrder()
                .renumberedBySiblingOrder()
            lastErrorMessage = "Could not load todos: \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            try persistence.saveSnapshot(
                TodoPersistenceSnapshot(
                    items: items,
                    recurrentEvents: recurrentEvents,
                    tags: tags,
                    trashItems: trashItems
                )
            )
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Could not save todos: \(error.localizedDescription)"
        }
    }

    @discardableResult
    public func generateDueRecurrences(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        let occurrenceDay = calendar.startOfDay(for: referenceDate)
        var generatedItems: [TodoItem] = []

        for event in recurrentEvents {
            guard let dueDate = event.dueDate,
                  let recurrenceRule = event.recurrenceRule,
                  recurrenceRule.occurs(on: occurrenceDay, starting: dueDate, calendar: calendar),
                  !items.contains(where: {
                      $0.recurrenceSourceID == event.id
                        && $0.recurrenceOccurrenceDate.map { calendar.isDate($0, inSameDayAs: occurrenceDay) } == true
                  }) else {
                continue
            }

            generatedItems.append(
                event.recurrenceOccurrence(
                    occurrenceDate: occurrenceDay,
                    calendar: calendar
                )
            )
        }

        guard !generatedItems.isEmpty else {
            return false
        }

        items = (generatedItems + items).renumberedBySiblingOrder()
        return true
    }

    @discardableResult
    public func applyLifecycle(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let cutoffDate = calendar.date(byAdding: .day, value: -3, to: referenceDate) else {
            return false
        }

        let expiredTrashIDs = Set(
            trashItems.compactMap { item in
                item.deletedAt.map { $0 <= cutoffDate } == true ? item.id : nil
            }
        )
        let completedIDs = completedTodoIDs(cutoffDate: cutoffDate)
        var didChange = false

        if !expiredTrashIDs.isEmpty {
            clearTrash(ids: expiredTrashIDs)
            didChange = true
        }

        if !completedIDs.isEmpty {
            moveToTrash(ids: completedIDs, deletionDate: referenceDate)
            didChange = true
        }

        return didChange
    }

    private func nextTagName() -> String {
        var index = tags.count + 1

        while tags.contains(where: { $0.name == "Tag \(index)" }) {
            index += 1
        }

        return "Tag \(index)"
    }

    private static func defaultSeedSnapshot(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> TodoPersistenceSnapshot {
        if let demoSnapshot = try? TodoPersistence.loadDemoSnapshot() {
            return shiftedDemoSnapshot(demoSnapshot, referenceDate: referenceDate, calendar: calendar)
        }

        return TodoPersistenceSnapshot(items: sampleItems())
    }

    private static func shiftedDemoSnapshot(
        _ snapshot: TodoPersistenceSnapshot,
        referenceDate: Date,
        calendar: Calendar
    ) -> TodoPersistenceSnapshot {
        let demoBaseDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)) ?? referenceDate
        let dayOffset = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: demoBaseDate),
            to: calendar.startOfDay(for: referenceDate)
        ).day ?? 0

        return TodoPersistenceSnapshot(
            items: snapshot.items.shiftedDates(by: dayOffset, calendar: calendar),
            recurrentEvents: snapshot.recurrentEvents.shiftedDates(by: dayOffset, calendar: calendar),
            tags: snapshot.tags,
            trashItems: snapshot.trashItems.shiftedDates(by: dayOffset, calendar: calendar)
        )
    }

    private enum MovePlacement {
        case before
        case after
    }

    private struct RemovedTodo {
        var item: TodoItem
        var origin: TodoTrashOrigin
        var parentID: TodoItem.ID?
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

    private func removeTodoForTrash(id: TodoItem.ID) -> RemovedTodo? {
        if let index = items.firstIndex(where: { $0.id == id }) {
            return RemovedTodo(item: items.remove(at: index), origin: .active, parentID: nil)
        }

        if let index = recurrentEvents.firstIndex(where: { $0.id == id }) {
            return RemovedTodo(item: recurrentEvents.remove(at: index), origin: .recurrent, parentID: nil)
        }

        for index in items.indices {
            if let removedItem = items[index].removeSubtaskWithParent(id: id) {
                return RemovedTodo(item: removedItem.item, origin: .active, parentID: removedItem.parentID)
            }
        }

        for index in recurrentEvents.indices {
            if let removedItem = recurrentEvents[index].removeSubtaskWithParent(id: id) {
                return RemovedTodo(item: removedItem.item, origin: .recurrent, parentID: removedItem.parentID)
            }
        }

        return nil
    }

    private func removeTrashTodo(id: TodoItem.ID) -> TodoItem? {
        if let index = trashItems.firstIndex(where: { $0.id == id }) {
            return trashItems.remove(at: index)
        }

        for index in trashItems.indices {
            if let removedItem = trashItems[index].removeSubtask(id: id) {
                return removedItem
            }
        }

        return nil
    }

    private func recover(
        _ item: TodoItem,
        parentID: TodoItem.ID?,
        intoRecurrentEvents: Bool
    ) {
        if let parentID {
            if intoRecurrentEvents {
                for index in recurrentEvents.indices where recurrentEvents[index].insertSubtask(item, intoParent: parentID) {
                    return
                }
            } else {
                for index in items.indices where items[index].insertSubtask(item, intoParent: parentID) {
                    return
                }
            }
        }

        if intoRecurrentEvents {
            recurrentEvents.insert(item, at: 0)
        } else {
            items.insert(item, at: 0)
        }
    }

    private func completedTodoIDs(cutoffDate: Date? = nil) -> Set<TodoItem.ID> {
        let allItems = items + recurrentEvents

        return Set(
            allItems.flatMap { item in
                item.completedTrashIDs(cutoffDate: cutoffDate)
            }
        )
    }

    private func todoIDsWithTag(id tagID: TodoTag.ID) -> Set<TodoItem.ID> {
        Set(
            (items + recurrentEvents)
                .filter { $0.containsTag(id: tagID) }
                .map(\.id)
        )
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
                    subtask.completeIncludingSubtasks(completionDate: Date())
                }

                subtask.tagID = items[index].tagID
                subtask.propagateTagToSubtasks()
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
    struct RemovedSubtask {
        var item: TodoItem
        var parentID: TodoItem.ID
    }

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

    func todoIDs(where predicate: (TodoItem) -> Bool) -> [TodoItem.ID] {
        var ids = predicate(self) ? [id] : []

        for subtask in subtasks {
            ids.append(contentsOf: subtask.todoIDs(where: predicate))
        }

        return ids
    }

    func completedTrashIDs(cutoffDate: Date?) -> [TodoItem.ID] {
        if isCompleted {
            if let cutoffDate {
                if completedAt.map({ $0 <= cutoffDate }) == true {
                    return [id]
                }
            } else {
                return [id]
            }
        }

        return subtasks.flatMap { $0.completedTrashIDs(cutoffDate: cutoffDate) }
    }

    func containsTodo(id: TodoItem.ID) -> Bool {
        todo(id: id) != nil
    }

    func parentTodo(for childID: TodoItem.ID) -> TodoItem? {
        if subtasks.contains(where: { $0.id == childID }) {
            return self
        }

        for subtask in subtasks {
            if let match = subtask.parentTodo(for: childID) {
                return match
            }
        }

        return nil
    }

    func containsTag(id tagID: TodoTag.ID) -> Bool {
        self.tagID == tagID || subtasks.contains { $0.containsTag(id: tagID) }
    }

    mutating func propagateTagToSubtasks() {
        for index in subtasks.indices {
            subtasks[index].tagID = tagID
            subtasks[index].propagateTagToSubtasks()
        }
    }

    mutating func clearTag(id tagID: TodoTag.ID) {
        if self.tagID == tagID {
            self.tagID = nil
        }

        for index in subtasks.indices {
            subtasks[index].clearTag(id: tagID)
        }
    }

    mutating func prepareForTrash(
        origin: TodoTrashOrigin,
        parentID: TodoItem.ID?,
        deletionDate: Date
    ) {
        deletedAt = deletionDate
        trashOrigin = origin
        deletedParentID = parentID

        for index in subtasks.indices {
            subtasks[index].prepareForTrash(
                origin: origin,
                parentID: id,
                deletionDate: deletionDate
            )
        }
    }

    mutating func restoreFromTrash() {
        deletedAt = nil
        trashOrigin = nil
        deletedParentID = nil

        for index in subtasks.indices {
            subtasks[index].restoreFromTrash()
        }
    }

    mutating func applyCompletionState(from previousItem: TodoItem, completionDate: Date) {
        if !previousItem.isCompleted, isCompleted {
            completedAt = completedAt ?? completionDate
            completeIncludingSubtasks(completionDate: completedAt ?? completionDate)
        } else if previousItem.isCompleted, !isCompleted {
            completedAt = nil
            clearCompletionDates()
        } else if isCompleted, completedAt == nil {
            completedAt = completionDate
        }
    }

    func updated(with replacement: TodoItem) -> TodoItem {
        var updatedItem = replacement

        if !isCompleted, updatedItem.isCompleted {
            updatedItem.completeIncludingSubtasks(completionDate: Date())
        }

        return updatedItem
    }

    mutating func updateSubtask(_ replacement: TodoItem, completionDate: Date) -> Bool {
        for index in subtasks.indices {
            if subtasks[index].id == replacement.id {
                var updatedItem = subtasks[index].updated(with: replacement)
                updatedItem.applyCompletionState(from: subtasks[index], completionDate: completionDate)
                subtasks[index] = updatedItem
                return true
            }

            if subtasks[index].updateSubtask(replacement, completionDate: completionDate) {
                return true
            }
        }

        return false
    }

    mutating func toggleCompletionIncludingSubtasksWhenCompleted(completionDate: Date) {
        isCompleted.toggle()

        if isCompleted {
            completeIncludingSubtasks(completionDate: completionDate)
        } else {
            clearCompletionDates()
        }
    }

    mutating func toggleSubtaskCompletion(id: TodoItem.ID, completionDate: Date) -> Bool {
        for index in subtasks.indices {
            if subtasks[index].id == id {
                subtasks[index].toggleCompletionIncludingSubtasksWhenCompleted(completionDate: completionDate)
                return true
            }

            if subtasks[index].toggleSubtaskCompletion(id: id, completionDate: completionDate) {
                return true
            }
        }

        return false
    }

    mutating func completeIncludingSubtasks(completionDate: Date) {
        isCompleted = true
        completedAt = completedAt ?? completionDate

        for index in subtasks.indices {
            subtasks[index].completeIncludingSubtasks(completionDate: completionDate)
        }
    }

    mutating func clearCompletionDates() {
        completedAt = nil

        for index in subtasks.indices {
            subtasks[index].clearCompletionDates()
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

    mutating func removeSubtaskWithParent(id: TodoItem.ID) -> RemovedSubtask? {
        if let index = subtasks.firstIndex(where: { $0.id == id }) {
            return RemovedSubtask(item: subtasks.remove(at: index), parentID: self.id)
        }

        for index in subtasks.indices {
            if let removedItem = subtasks[index].removeSubtaskWithParent(id: id) {
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
                subtask.completeIncludingSubtasks(completionDate: Date())
            }

            subtask.tagID = tagID
            subtask.propagateTagToSubtasks()
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

    func recurrenceOccurrence(
        occurrenceDate: Date,
        calendar: Calendar
    ) -> TodoItem {
        var occurrence = copyWithFreshIDs()
        occurrence.dueDate = calendar.startOfDay(for: occurrenceDate)
        occurrence.endDate = nil
        occurrence.recurrenceRule = nil
        occurrence.recurrenceSourceID = id
        occurrence.recurrenceOccurrenceDate = calendar.startOfDay(for: occurrenceDate)
        occurrence.applyRecurrenceSource(id: id, occurrenceDate: occurrenceDate, calendar: calendar)
        return occurrence
    }

    private func copyWithFreshIDs() -> TodoItem {
        var copy = self
        copy.id = UUID()
        copy.subtasks = subtasks.map { $0.copyWithFreshIDs() }
        return copy
    }

    private mutating func applyRecurrenceSource(
        id sourceID: TodoItem.ID,
        occurrenceDate: Date,
        calendar: Calendar
    ) {
        recurrenceSourceID = sourceID
        recurrenceOccurrenceDate = calendar.startOfDay(for: occurrenceDate)
        recurrenceRule = nil

        for index in subtasks.indices {
            subtasks[index].applyRecurrenceSource(
                id: sourceID,
                occurrenceDate: occurrenceDate,
                calendar: calendar
            )
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

    func shiftedDates(by dayOffset: Int, calendar: Calendar) -> [TodoItem] {
        map { item in
            var shiftedItem = item
            shiftedItem.shiftDates(by: dayOffset, calendar: calendar)
            return shiftedItem
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

private extension Array where Element == TodoTag {
    func renumberedByTagOrder() -> [TodoTag] {
        enumerated().map { index, tag in
            var updatedTag = tag
            updatedTag.order = index
            return updatedTag
        }
    }
}

private extension TodoItem {
    mutating func shiftDates(by dayOffset: Int, calendar: Calendar) {
        dueDate = dueDate.flatMap { calendar.date(byAdding: .day, value: dayOffset, to: $0) }
        endDate = endDate.flatMap { calendar.date(byAdding: .day, value: dayOffset, to: $0) }
        completedAt = completedAt.flatMap { calendar.date(byAdding: .day, value: dayOffset, to: $0) }
        deletedAt = deletedAt.flatMap { calendar.date(byAdding: .day, value: dayOffset, to: $0) }
        recurrenceOccurrenceDate = recurrenceOccurrenceDate.flatMap {
            calendar.date(byAdding: .day, value: dayOffset, to: $0)
        }

        for index in subtasks.indices {
            subtasks[index].shiftDates(by: dayOffset, calendar: calendar)
        }
    }

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
