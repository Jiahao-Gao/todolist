import XCTest
@testable import TodoCore

@MainActor
final class TodoStoreTests: XCTestCase {
    func testTodoFilterOrderPlacesOverdueBelowCompleted() {
        XCTAssertEqual(
            TodoFilter.allCases.map(\.title),
            ["All", "Today", "Upcoming", "Completed", "Overdue", "Recurrent"]
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
            [upcoming.id]
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

    func testSortAllByDateSortsSubtasksThenMainTasksAndKeepsTiesStable() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let calendar = Calendar(identifier: .gregorian)
        let dayOne = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 4)))
        let dayTwo = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: dayOne))
        let dayThree = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: dayOne))

        let noDateMain = store.addTodo(title: "No date")
        let dayThreeA = store.addTodo(title: "Day three A", dueDate: dayThree)
        let dayThreeB = store.addTodo(title: "Day three B", dueDate: dayThree)
        let parent = store.addTodo(title: "Parent")
        let noDateChild = try XCTUnwrap(store.addSubtask(to: parent.id, title: "No date child"))
        let dayTwoA = try XCTUnwrap(store.addSubtask(to: parent.id, title: "Day two A", dueDate: dayTwo))
        let dayOneChild = try XCTUnwrap(store.addSubtask(to: parent.id, title: "Day one", dueDate: dayOne))
        let dayTwoB = try XCTUnwrap(store.addSubtask(to: parent.id, title: "Day two B", dueDate: dayTwo))

        store.sortAllByDate(calendar: calendar)

        XCTAssertEqual(
            store.filteredItems(for: .all).map(\.id),
            [parent.id, dayThreeB.id, dayThreeA.id, noDateMain.id]
        )
        XCTAssertEqual(
            store.todo(id: parent.id)?.subtasks.map(\.id),
            [dayOneChild.id, dayTwoB.id, dayTwoA.id, noDateChild.id]
        )
        XCTAssertEqual(store.filteredItems(for: .all).map(\.order), [0, 1, 2, 3])
        XCTAssertEqual(store.todo(id: parent.id)?.subtasks.map(\.order), [0, 1, 2, 3])

        let reloadedStore = TodoStore(persistence: persistence, seedSamples: false)
        XCTAssertEqual(
            reloadedStore.filteredItems(for: .all).map(\.id),
            [parent.id, dayThreeB.id, dayThreeA.id, noDateMain.id]
        )
        XCTAssertEqual(
            reloadedStore.todo(id: parent.id)?.subtasks.map(\.id),
            [dayOneChild.id, dayTwoB.id, dayTwoA.id, noDateChild.id]
        )
    }

    func testDateFiltersUseInternalOrderInsteadOfDateOrder() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 3)))
        let earlier = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: referenceDate))
        let later = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: referenceDate))

        let earlierTask = store.addTodo(title: "Earlier", dueDate: earlier)
        let laterTask = store.addTodo(title: "Later", dueDate: later)

        XCTAssertEqual(
            store.filteredItems(for: .upcoming, referenceDate: referenceDate, calendar: calendar).map(\.id),
            [laterTask.id, earlierTask.id]
        )
    }

    func testUpdatingMainTaskWithRecurrenceMovesItToRecurrentEvents() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let calendar = Calendar(identifier: .gregorian)
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 4)))

        var task = store.addTodo(title: "Plan standup", dueDate: startDate)
        task.recurrenceRule = RecurrenceRule(frequency: .weekly, weekday: 2)
        store.update(task)

        XCTAssertNil(store.items.first { $0.id == task.id })
        XCTAssertEqual(store.filteredItems(for: .recurrent).map(\.id), [task.id])

        var event = try XCTUnwrap(store.todo(id: task.id))
        event.recurrenceRule = nil
        store.update(event)

        XCTAssertEqual(store.filteredItems(for: .recurrent).map(\.id), [])
        XCTAssertEqual(store.filteredItems(for: .all).map(\.id), [task.id])
    }

    func testGenerateDueRecurrencesCreatesOneNormalTaskForMatchingDay() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let calendar = Calendar(identifier: .gregorian)
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 4)))

        var event = store.addTodo(title: "Weekly sync", dueDate: monday)
        event.notes = "Carry notes"
        event.recurrenceRule = RecurrenceRule(frequency: .weekly, weekday: 2, occurrenceLimit: 2)
        store.update(event)

        XCTAssertTrue(store.generateDueRecurrences(referenceDate: monday, calendar: calendar))
        XCTAssertFalse(store.generateDueRecurrences(referenceDate: monday, calendar: calendar))

        let generated = try XCTUnwrap(store.filteredItems(for: .today, referenceDate: monday, calendar: calendar).first)
        XCTAssertNotEqual(generated.id, event.id)
        XCTAssertEqual(generated.title, "Weekly sync")
        XCTAssertEqual(generated.notes, "Carry notes")
        XCTAssertEqual(generated.recurrenceSourceID, event.id)
        XCTAssertNil(generated.recurrenceRule)
        XCTAssertEqual(store.recurrenceSource(for: generated)?.id, event.id)
    }

    func testRecurrenceOccurrenceLimitStopsFutureGeneration() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let calendar = Calendar(identifier: .gregorian)
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 4)))
        let secondMonday = try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: monday))
        let thirdMonday = try XCTUnwrap(calendar.date(byAdding: .day, value: 14, to: monday))

        var event = store.addTodo(title: "Two Mondays", dueDate: monday)
        event.recurrenceRule = RecurrenceRule(frequency: .weekly, weekday: 2, occurrenceLimit: 2)
        store.update(event)

        XCTAssertTrue(store.generateDueRecurrences(referenceDate: monday, calendar: calendar))
        XCTAssertTrue(store.generateDueRecurrences(referenceDate: secondMonday, calendar: calendar))
        XCTAssertFalse(store.generateDueRecurrences(referenceDate: thirdMonday, calendar: calendar))
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

    func testUpcomingStartsTomorrowAndRunsThroughTwoWeeks() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 4)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: now))
        let twoWeeks = try XCTUnwrap(calendar.date(byAdding: .day, value: 14, to: now))
        let beyondWindow = try XCTUnwrap(calendar.date(byAdding: .day, value: 15, to: now))

        _ = store.addTodo(title: "Already past", dueDate: yesterday)
        _ = store.addTodo(title: "Start now", dueDate: now)
        let tomorrowStart = store.addTodo(title: "Tomorrow", dueDate: tomorrow)
        let finalWindowDay = store.addTodo(title: "Still upcoming", dueDate: twoWeeks)
        _ = store.addTodo(title: "Later", dueDate: beyondWindow)

        XCTAssertEqual(
            store.filteredItems(for: .upcoming, referenceDate: now, calendar: calendar).map(\.id),
            [finalWindowDay.id, tomorrowStart.id]
        )
    }

    func testTodayIncludesTasksBetweenStartAndEndDates() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 4)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: now))

        let activeRange = store.addTodo(title: "Active range", dueDate: yesterday, endDate: tomorrow)
        _ = store.addTodo(title: "Starts tomorrow", dueDate: tomorrow)

        XCTAssertEqual(
            store.filteredItems(for: .today, referenceDate: now, calendar: calendar).map(\.id),
            [activeRange.id]
        )
    }

    func testOverdueUsesEndDateWhenPresent() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 4)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: now))
        let twoDaysAgo = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: now))

        let activeRange = store.addTodo(title: "Still active", dueDate: yesterday, endDate: tomorrow)
        let endedRange = store.addTodo(title: "Ended", dueDate: twoDaysAgo, endDate: yesterday)
        let noEnd = store.addTodo(title: "No end", dueDate: yesterday)

        XCTAssertEqual(
            store.filteredItems(for: .overdue, referenceDate: now, calendar: calendar).map(\.id),
            [noEnd.id, endedRange.id]
        )
        XCTAssertFalse(activeRange.isOverdue(referenceDate: now, calendar: calendar))
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
        let upcomingChildMatchedMain = try XCTUnwrap(upcomingItems.first { $0.id == childMatchedMain.id })

        XCTAssertNil(upcomingItems.first { $0.id == dueMain.id })
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
        let endDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: dueDate))

        let main = store.addTodo(title: "Plan launch", dueDate: dueDate, endDate: endDate)
        let subtask = try XCTUnwrap(store.addSubtask(to: main.id, title: "Draft notes"))

        XCTAssertEqual(subtask.dueDate, dueDate)
        XCTAssertEqual(subtask.endDate, endDate)
        XCTAssertEqual(store.todo(id: main.id)?.subtasks.map(\.id), [subtask.id])
        XCTAssertEqual(store.todo(id: subtask.id)?.title, "Draft notes")

        let reloadedStore = TodoStore(persistence: persistence, seedSamples: false)
        XCTAssertEqual(reloadedStore.todo(id: main.id)?.subtasks.first?.id, subtask.id)
        XCTAssertEqual(reloadedStore.todo(id: subtask.id)?.dueDate, dueDate)
        XCTAssertEqual(reloadedStore.todo(id: subtask.id)?.endDate, endDate)
    }

    func testTagsFilterMainTasksAndAreInheritedBySubtasks() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let tag = store.addTag(name: "Work")
        var main = store.addTodo(title: "Launch")
        main.tagID = tag.id
        store.update(main)
        let subtask = try XCTUnwrap(store.addSubtask(to: main.id, title: "Draft"))
        _ = store.addTodo(title: "Personal")

        XCTAssertEqual(store.filteredItems(forTag: tag.id).map(\.id), [main.id])
        XCTAssertEqual(store.todo(id: subtask.id)?.tagID, tag.id)
        XCTAssertEqual(store.effectiveTag(for: try XCTUnwrap(store.todo(id: subtask.id)))?.id, tag.id)

        store.deleteTag(id: tag.id)

        XCTAssertTrue(store.tags.isEmpty)
        XCTAssertNil(store.todo(id: main.id)?.tagID)
        XCTAssertNil(store.todo(id: subtask.id)?.tagID)
    }

    func testDeleteMovesTaskToTrashAndRecoverRestoresIt() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let task = store.addTodo(title: "Restore me")

        store.delete(id: task.id)

        XCTAssertNil(store.todo(id: task.id))
        XCTAssertEqual(store.filteredTrashItems().map(\.id), [task.id])
        XCTAssertEqual(store.trashTodo(id: task.id)?.trashOrigin, .active)
        XCTAssertNotNil(store.trashTodo(id: task.id)?.deletedAt)

        store.recoverTrash(ids: [task.id])

        XCTAssertEqual(store.filteredItems(for: .all).map(\.id), [task.id])
        XCTAssertNil(store.trashTodo(id: task.id))
        XCTAssertNil(store.todo(id: task.id)?.deletedAt)
    }

    func testClearTrashPermanentlyRemovesTask() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let task = store.addTodo(title: "Clear me")

        store.delete(id: task.id)
        store.clearTrash(ids: [task.id])

        XCTAssertNil(store.todo(id: task.id))
        XCTAssertNil(store.trashTodo(id: task.id))
        XCTAssertTrue(store.filteredTrashItems().isEmpty)
    }

    func testRecoveringRecurrentEventReturnsItToRecurrentEvents() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let calendar = Calendar(identifier: .gregorian)
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 4)))

        var event = store.addTodo(title: "Weekly sync", dueDate: startDate)
        event.recurrenceRule = RecurrenceRule(frequency: .weekly, weekday: 2)
        store.update(event)

        store.delete(id: event.id)

        XCTAssertNil(store.todo(id: event.id))
        XCTAssertEqual(store.trashTodo(id: event.id)?.trashOrigin, .recurrent)

        store.recoverTrash(ids: [event.id])

        XCTAssertEqual(store.filteredItems(for: .recurrent).map(\.id), [event.id])
        XCTAssertEqual(store.filteredItems(for: .all).map(\.id), [])
    }

    func testDeleteTagAndTasksMovesTaggedTasksToTrash() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let tag = store.addTag(name: "Work")
        var taggedTask = store.addTodo(title: "Tagged")
        taggedTask.tagID = tag.id
        store.update(taggedTask)
        let untaggedTask = store.addTodo(title: "Untagged")

        store.deleteTagAndTasks(id: tag.id)

        XCTAssertTrue(store.tags.isEmpty)
        XCTAssertNil(store.todo(id: taggedTask.id))
        XCTAssertNotNil(store.trashTodo(id: taggedTask.id))
        XCTAssertNotNil(store.todo(id: untaggedTask.id))
    }

    func testLifecycleMovesOldCompletedTasksAndClearsOldTrash() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 5)))
        let oldDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let recentDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 4)))

        var oldCompleted = store.addTodo(title: "Old completed")
        oldCompleted.isCompleted = true
        oldCompleted.completedAt = oldDate
        store.update(oldCompleted)

        var recentCompleted = store.addTodo(title: "Recent completed")
        recentCompleted.isCompleted = true
        recentCompleted.completedAt = recentDate
        store.update(recentCompleted)

        let oldTrash = store.addTodo(title: "Old trash")
        let recentTrash = store.addTodo(title: "Recent trash")
        store.moveToTrash(ids: [oldTrash.id], deletionDate: oldDate)
        store.moveToTrash(ids: [recentTrash.id], deletionDate: recentDate)

        XCTAssertTrue(store.applyLifecycle(referenceDate: referenceDate, calendar: calendar))

        XCTAssertNil(store.todo(id: oldCompleted.id))
        XCTAssertNotNil(store.trashTodo(id: oldCompleted.id))
        XCTAssertNotNil(store.todo(id: recentCompleted.id))
        XCTAssertNil(store.trashTodo(id: oldTrash.id))
        XCTAssertNotNil(store.trashTodo(id: recentTrash.id))
    }

    func testTagsPersistWithSnapshot() throws {
        let persistence = TodoPersistence(fileURL: try temporaryFileURL())
        let store = TodoStore(persistence: persistence, seedSamples: false)
        let tag = store.addTag(name: "Errands")
        store.updateTagColor(id: tag.id, color: .purple)
        var task = store.addTodo(title: "Buy stamps")
        task.tagID = tag.id
        store.update(task)

        let reloadedStore = TodoStore(persistence: persistence, seedSamples: false)
        let reloadedTag = try XCTUnwrap(reloadedStore.tags.first)

        XCTAssertEqual(reloadedTag.name, "Errands")
        XCTAssertEqual(reloadedTag.color, .purple)
        XCTAssertEqual(reloadedStore.todo(id: task.id)?.tagID, tag.id)
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
        XCTAssertNil(item.endDate)
        XCTAssertEqual(item.order, 0)
        XCTAssertTrue(item.subtasks.isEmpty)
    }

    func testLoadsSnapshotWithoutTrashItems() throws {
        let fileURL = try temporaryFileURL()
        let todoID = UUID()
        let legacySnapshotJSON = """
        {
          "items": [
            {
              "id": "\(todoID.uuidString)",
              "title": "Snapshot todo",
              "isCompleted": false
            }
          ],
          "recurrentEvents": [],
          "tags": []
        }
        """

        try XCTUnwrap(legacySnapshotJSON.data(using: .utf8)).write(to: fileURL)

        let snapshot = try TodoPersistence.loadSnapshot(from: fileURL)

        XCTAssertEqual(snapshot.items.map(\.id), [todoID])
        XCTAssertTrue(snapshot.trashItems.isEmpty)
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
