import Foundation

public enum TodoFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case today
    case upcoming
    case completed
    case overdue

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all:
            "All"
        case .today:
            "Today"
        case .upcoming:
            "Upcoming"
        case .overdue:
            "Overdue"
        case .completed:
            "Completed"
        }
    }

    public var systemImage: String {
        switch self {
        case .all:
            "list.bullet"
        case .today:
            "calendar"
        case .upcoming:
            "clock"
        case .overdue:
            "exclamationmark.triangle"
        case .completed:
            "checkmark.circle"
        }
    }

    public func includes(_ item: TodoItem, referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            !item.isCompleted
        case .today:
            !item.isCompleted && (item.dueDate.map { calendar.isDate($0, inSameDayAs: referenceDate) } ?? false)
        case .upcoming:
            !item.isCompleted && isWithinUpcomingWindow(item.dueDate, referenceDate: referenceDate, calendar: calendar)
        case .overdue:
            !item.isCompleted && isOverdue(item.dueDate, referenceDate: referenceDate, calendar: calendar)
        case .completed:
            item.isCompleted
        }
    }

    private func isWithinUpcomingWindow(
        _ dueDate: Date?,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard let dueDate,
              let windowEnd = calendar.date(byAdding: .day, value: 14, to: calendar.startOfDay(for: referenceDate)) else {
            return false
        }

        let dueDay = calendar.startOfDay(for: dueDate)
        let windowStart = calendar.startOfDay(for: referenceDate)

        return dueDay >= windowStart && dueDay <= windowEnd
    }

    private func isOverdue(
        _ dueDate: Date?,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard let dueDate else {
            return false
        }

        return calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: referenceDate)
    }
}
