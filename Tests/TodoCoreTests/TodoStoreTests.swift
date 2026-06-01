import XCTest
@testable import TodoCore

@MainActor
final class TodoStoreTests: XCTestCase {
    func testTodoFilterOrderPlacesOverdueBelowCompleted() {
        XCTAssertEqual(
            TodoFilter.allCases.map(\.title),
            ["All", "Today", "Upcoming", "Completed", "Overdue"]
        )
    }

    func testAddUpdateToggleAndReload() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)

        let item = store.addTodo(
            title: "Write tests",
            notes: "Cover the starter store behavior."
        )

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.title, "Write tests")

        var updated = try XCTUnwrap(store.todo(id: item.id))
        updated.title = "Write focused tests"
        store.update(updated)

        store.toggleCompletion(id: item.id)

        let reloadedStore = TodoStore(persistence: persistence, seedSamples: false)
        let reloadedItem = try XCTUnwrap(reloadedStore.todo(id: item.id))

        XCTAssertEqual(reloadedItem.title, "Write focused tests")
        XCTAssertTrue(reloadedItem.isCompleted)
    }

    func testFilteringAndSearch() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 4)))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: now))

        let today = store.addTodo(title: "Ship starter", dueDate: now)
        let upcoming = store.addTodo(title: "Polish details", dueDate: tomorrow)
        let completed = store.addTodo(title: "Archive example")
        store.toggleCompletion(id: completed.id)

        XCTAssertEqual(
            store.filteredItems(for: .today, referenceDate: now, calendar: calendar).map(\.id),
            [today.id]
        )
        XCTAssertEqual(
            store.filteredItems(for: .upcoming, referenceDate: now, calendar: calendar).map(\.id),
            [today.id, upcoming.id]
        )
        XCTAssertEqual(
            store.filteredItems(for: .completed, referenceDate: now, calendar: calendar).map(\.id),
            [completed.id]
        )
        XCTAssertEqual(
            store.filteredItems(for: .overdue, referenceDate: now, calendar: calendar).map(\.id),
            []
        )
        XCTAssertEqual(
            store.filteredItems(for: .all, referenceDate: now, calendar: calendar).map(\.id),
            [upcoming.id, today.id]
        )
        XCTAssertEqual(
            store.filteredItems(for: .all, searchText: "polish", referenceDate: now, calendar: calendar).map(\.id),
            [upcoming.id]
        )
    }

    func testAllFilterPreservesManualOrder() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)

        let first = store.addTodo(title: "First")
        let second = store.addTodo(title: "Second")
        let third = store.addTodo(title: "Third")

        XCTAssertEqual(store.filteredItems(for: .all).map(\.id), [third.id, second.id, first.id])

        store.moveTodo(id: first.id, before: third.id)

        XCTAssertEqual(store.filteredItems(for: .all).map(\.id), [first.id, third.id, second.id])

        let reloadedStore = TodoStore(persistence: persistence, seedSamples: false)
        XCTAssertEqual(reloadedStore.filteredItems(for: .all).map(\.id), [first.id, third.id, second.id])
    }

    func testMoveSubtaskWithinParentOrder() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)

        let parent = store.addTodo(title: "Parent")
        let first = try XCTUnwrap(store.addSubtask(to: parent.id, title: "First child"))
        let second = try XCTUnwrap(store.addSubtask(to: parent.id, title: "Second child"))

        XCTAssertEqual(store.todo(id: parent.id)?.subtasks.map(\.id), [second.id, first.id])

        store.moveTodo(id: first.id, before: second.id)

        XCTAssertEqual(store.todo(id: parent.id)?.subtasks.map(\.id), [first.id, second.id])
    }

    func testMoveMainAndSubtaskUnderMainTask() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)

        let targetParent = store.addTodo(title: "Target")
        let movingMain = store.addTodo(title: "Moving main")
        let sourceParent = store.addTodo(title: "Source")
        let movingSubtask = try XCTUnwrap(store.addSubtask(to: sourceParent.id, title: "Moving subtask"))

        store.moveTodo(id: movingMain.id, asSubtaskOf: targetParent.id)

        XCTAssertNil(store.items.first { $0.id == movingMain.id })
        XCTAssertEqual(store.todo(id: targetParent.id)?.subtasks.map(\.id), [movingMain.id])

        store.moveTodo(id: movingSubtask.id, asSubtaskOf: targetParent.id)

        XCTAssertEqual(store.todo(id: sourceParent.id)?.subtasks.map(\.id), [])
        XCTAssertEqual(store.todo(id: targetParent.id)?.subtasks.map(\.id), [movingMain.id, movingSubtask.id])
    }

    func testMoveSubtaskBackToMainTaskLevel() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)

        let parent = store.addTodo(title: "Parent")
        let existingMain = store.addTodo(title: "Existing main")
        let subtask = try XCTUnwrap(store.addSubtask(to: parent.id, title: "Nested item"))

        store.moveTodoToEndAsMain(id: subtask.id)

        XCTAssertEqual(store.todo(id: parent.id)?.subtasks.map(\.id), [])
        XCTAssertEqual(store.filteredItems(for: .all).map(\.id), [existingMain.id, parent.id, subtask.id])
    }

    func testUpcomingIncludesTodayThroughTwoWeeks() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 4)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        let twoWeeks = try XCTUnwrap(calendar.date(byAdding: .day, value: 14, to: now))
        let beyondWindow = try XCTUnwrap(calendar.date(byAdding: .day, value: 15, to: now))

        _ = store.addTodo(title: "Already past", dueDate: yesterday)
        let today = store.addTodo(title: "Start now", dueDate: now)
        let finalWindowDay = store.addTodo(title: "Still upcoming", dueDate: twoWeeks)
        _ = store.addTodo(title: "Later", dueDate: beyondWindow)

        XCTAssertEqual(
            store.filteredItems(for: .upcoming, referenceDate: now, calendar: calendar).map(\.id),
            [today.id, finalWindowDay.id]
        )
    }

    func testDateFiltersReturnMatchingMainTaskWithAllSubtasks() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 4)))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: now))
        let nextMonth = try XCTUnwrap(calendar.date(byAdding: .day, value: 30, to: now))

        let dueMain = store.addTodo(title: "Parent due today", dueDate: now)
        let dueMainUndatedSubtask = try XCTUnwrap(store.addSubtask(to: dueMain.id, title: "Undated child"))
        let dueMainFutureSubtask = try XCTUnwrap(
            store.addSubtask(to: dueMain.id, title: "Future child", dueDate: nextMonth)
        )

        let childMatchedMain = store.addTodo(title: "Parent due later", dueDate: nextMonth)
        let todaySubtask = try XCTUnwrap(store.addSubtask(to: childMatchedMain.id, title: "Today child", dueDate: now))
        let tomorrowSubtask = try XCTUnwrap(
            store.addSubtask(to: childMatchedMain.id, title: "Tomorrow child", dueDate: tomorrow)
        )
        let undatedSubtask = try XCTUnwrap(store.addSubtask(to: childMatchedMain.id, title: "Undated child"))

        let todayItems = store.filteredItems(for: .today, referenceDate: now, calendar: calendar)
        let todayDueMain = try XCTUnwrap(todayItems.first { $0.id == dueMain.id })
        let todayChildMatchedMain = try XCTUnwrap(todayItems.first { $0.id == childMatchedMain.id })

        XCTAssertEqual(
            Set(todayDueMain.subtasks.map(\.id)),
            Set([dueMainUndatedSubtask.id, dueMainFutureSubtask.id])
        )
        XCTAssertEqual(
            Set(todayChildMatchedMain.subtasks.map(\.id)),
            Set([todaySubtask.id, tomorrowSubtask.id, undatedSubtask.id])
        )

        let upcomingItems = store.filteredItems(for: .upcoming, referenceDate: now, calendar: calendar)
        let upcomingDueMain = try XCTUnwrap(upcomingItems.first { $0.id == dueMain.id })
        let upcomingChildMatchedMain = try XCTUnwrap(upcomingItems.first { $0.id == childMatchedMain.id })

        XCTAssertEqual(
            Set(upcomingDueMain.subtasks.map(\.id)),
            Set([dueMainUndatedSubtask.id, dueMainFutureSubtask.id])
        )
        XCTAssertEqual(
            Set(upcomingChildMatchedMain.subtasks.map(\.id)),
            Set([todaySubtask.id, tomorrowSubtask.id, undatedSubtask.id])
        )
    }

    func testOverdueFilterReturnsFullMainTaskGroupWhenMainOrSubtaskIsOverdue() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 4)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: now))

        let overdueMain = store.addTodo(title: "Main overdue", dueDate: yesterday)
        let overdueMainSubtask = try XCTUnwrap(store.addSubtask(to: overdueMain.id, title: "Included child"))
        let childMatchedMain = store.addTodo(title: "Child overdue", dueDate: tomorrow)
        let overdueSubtask = try XCTUnwrap(store.addSubtask(to: childMatchedMain.id, title: "Overdue child", dueDate: yesterday))
        let futureSubtask = try XCTUnwrap(store.addSubtask(to: childMatchedMain.id, title: "Future child", dueDate: tomorrow))

        let overdueItems = store.filteredItems(for: .overdue, referenceDate: now, calendar: calendar)
        let overdueMainResult = try XCTUnwrap(overdueItems.first { $0.id == overdueMain.id })
        let childMatchedMainResult = try XCTUnwrap(overdueItems.first { $0.id == childMatchedMain.id })

        XCTAssertEqual(overdueMainResult.subtasks.map(\.id), [overdueMainSubtask.id])
        XCTAssertEqual(
            Set(childMatchedMainResult.subtasks.map(\.id)),
            Set([overdueSubtask.id, futureSubtask.id])
        )
    }

    func testAddSubtaskInheritsMainDueDateAndPersists() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let calendar = Calendar(identifier: .gregorian)
        let dueDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 4)))

        let main = store.addTodo(title: "Plan launch", dueDate: dueDate)
        let subtask = try XCTUnwrap(store.addSubtask(to: main.id, title: "Draft notes"))

        XCTAssertEqual(subtask.dueDate, dueDate)
        XCTAssertEqual(store.todo(id: main.id)?.subtasks.map(\.id), [subtask.id])
        XCTAssertEqual(store.todo(id: subtask.id)?.title, "Draft notes")

        let reloadedStore = TodoStore(persistence: persistence, seedSamples: false)
        XCTAssertEqual(reloadedStore.todo(id: main.id)?.subtasks.first?.id, subtask.id)
        XCTAssertEqual(reloadedStore.todo(id: subtask.id)?.dueDate, dueDate)
    }

    func testCompletingMainCompletesSubtasksButCompletedSubtasksDoNotCompleteMain() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)

        let main = store.addTodo(title: "Prepare demo")
        let firstSubtask = try XCTUnwrap(store.addSubtask(to: main.id, title: "Open project"))
        let secondSubtask = try XCTUnwrap(store.addSubtask(to: main.id, title: "Run app"))

        store.toggleCompletion(id: main.id)

        var completedMain = try XCTUnwrap(store.todo(id: main.id))
        XCTAssertTrue(completedMain.isCompleted)
        XCTAssertTrue(completedMain.subtasks.allSatisfy(\.isCompleted))

        let followUp = store.addTodo(title: "Write recap")
        let firstFollowUpSubtask = try XCTUnwrap(store.addSubtask(to: followUp.id, title: "Collect notes"))
        let secondFollowUpSubtask = try XCTUnwrap(store.addSubtask(to: followUp.id, title: "Send summary"))

        store.toggleCompletion(id: firstFollowUpSubtask.id)
        store.toggleCompletion(id: secondFollowUpSubtask.id)

        let incompleteMain = try XCTUnwrap(store.todo(id: followUp.id))
        XCTAssertFalse(incompleteMain.isCompleted)
        XCTAssertTrue(incompleteMain.subtasks.allSatisfy(\.isCompleted))

        completedMain.isCompleted = false
        store.update(completedMain)
        completedMain.isCompleted = true
        store.update(completedMain)

        XCTAssertTrue(try XCTUnwrap(store.todo(id: firstSubtask.id)).isCompleted)
        XCTAssertTrue(try XCTUnwrap(store.todo(id: secondSubtask.id)).isCompleted)
    }

    func testSearchMatchesSubtasksThroughMainTask() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)

        let main = store.addTodo(title: "Organize event")
        _ = try XCTUnwrap(store.addSubtask(to: main.id, title: "Book venue"))

        XCTAssertEqual(
            store.filteredItems(for: .all, searchText: "venue").map(\.id),
            [main.id]
        )
    }

    func testLoadsLegacyTodosWithoutSubtasks() throws {
        let fileURL = try temporaryFileURL()
        let legacyID = UUID()
        let legacyJSON = """
        [
          {
            "id": "\(legacyID.uuidString)",
            "title": "Legacy todo",
            "notes": "Created before subtasks existed.",
            "isCompleted": false
          }
        ]
        """

        try legacyJSON.data(using: .utf8)?.write(to: fileURL)

        let store = TodoStore(persistence: TodoPersistence(fileURL: fileURL), seedSamples: false)
        let item = try XCTUnwrap(store.todo(id: legacyID))

        XCTAssertEqual(item.title, "Legacy todo")
        XCTAssertTrue(item.subtasks.isEmpty)
    }

    private func temporaryFileURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory.appendingPathComponent("todos.json")
    }
}
