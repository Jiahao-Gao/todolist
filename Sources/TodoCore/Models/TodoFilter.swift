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
            !item.isCompleted && item.isDueToday(referenceDate: referenceDate, calendar: calendar)
        case .upcoming:
            !item.isCompleted && item.isUpcoming(referenceDate: referenceDate, calendar: calendar)
        case .overdue:
            item.isOverdue(referenceDate: referenceDate, calendar: calendar)
        case .completed:
            item.isCompleted
        }
    }
}
