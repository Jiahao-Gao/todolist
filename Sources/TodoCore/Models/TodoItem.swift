import Foundation

public struct TodoItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var isCompleted: Bool
    public var completedAt: Date?
    public var dueDate: Date?
    public var endDate: Date?
    public var order: Int
    public var tagID: UUID?
    public var recurrenceRule: RecurrenceRule?
    public var recurrenceSourceID: UUID?
    public var recurrenceOccurrenceDate: Date?
    public var deletedAt: Date?
    public var trashOrigin: TodoTrashOrigin?
    public var deletedParentID: UUID?
    public var subtasks: [TodoItem]

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        dueDate: Date? = nil,
        endDate: Date? = nil,
        order: Int = 0,
        tagID: UUID? = nil,
        recurrenceRule: RecurrenceRule? = nil,
        recurrenceSourceID: UUID? = nil,
        recurrenceOccurrenceDate: Date? = nil,
        deletedAt: Date? = nil,
        trashOrigin: TodoTrashOrigin? = nil,
        deletedParentID: UUID? = nil,
        subtasks: [TodoItem] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.dueDate = dueDate
        self.endDate = endDate
        self.order = order
        self.tagID = tagID
        self.recurrenceRule = recurrenceRule
        self.recurrenceSourceID = recurrenceSourceID
        self.recurrenceOccurrenceDate = recurrenceOccurrenceDate
        self.deletedAt = deletedAt
        self.trashOrigin = trashOrigin
        self.deletedParentID = deletedParentID
        self.subtasks = subtasks
    }

    public func matches(searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return true
        }

        return title.localizedCaseInsensitiveContains(query)
            || notes.localizedCaseInsensitiveContains(query)
            || subtasks.contains { $0.matches(searchText: query) }
    }

    public func isDueToday(referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let dueDate else {
            return false
        }

        let startDay = calendar.startOfDay(for: dueDate)
        let endDay = calendar.startOfDay(for: endDate ?? dueDate)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let rangeStart = min(startDay, endDay)
        let rangeEnd = max(startDay, endDay)

        return rangeStart <= referenceDay && referenceDay <= rangeEnd
    }

    public func isUpcoming(referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let dueDate,
              let windowStart = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate)),
              let windowEnd = calendar.date(byAdding: .day, value: 14, to: calendar.startOfDay(for: referenceDate)) else {
            return false
        }

        let dueDay = calendar.startOfDay(for: dueDate)

        return dueDay >= windowStart && dueDay <= windowEnd
    }

    public func isOverdue(referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let dueDate, !isCompleted else {
            return false
        }

        let overdueDate = endDate ?? dueDate

        return calendar.startOfDay(for: overdueDate) < calendar.startOfDay(for: referenceDate)
    }
}

public enum TodoTrashOrigin: String, Codable, Equatable, Sendable {
    case active
    case recurrent
}

extension TodoItem {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case isCompleted
        case completedAt
        case dueDate
        case endDate
        case order
        case tagID
        case recurrenceRule
        case recurrenceSourceID
        case recurrenceOccurrenceDate
        case deletedAt
        case trashOrigin
        case deletedParentID
        case subtasks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        tagID = try container.decodeIfPresent(UUID.self, forKey: .tagID)
        recurrenceRule = try container.decodeIfPresent(RecurrenceRule.self, forKey: .recurrenceRule)
        recurrenceSourceID = try container.decodeIfPresent(UUID.self, forKey: .recurrenceSourceID)
        recurrenceOccurrenceDate = try container.decodeIfPresent(Date.self, forKey: .recurrenceOccurrenceDate)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        trashOrigin = try container.decodeIfPresent(TodoTrashOrigin.self, forKey: .trashOrigin)
        deletedParentID = try container.decodeIfPresent(UUID.self, forKey: .deletedParentID)
        subtasks = try container.decodeIfPresent([TodoItem].self, forKey: .subtasks) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(notes, forKey: .notes)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(order, forKey: .order)
        try container.encodeIfPresent(tagID, forKey: .tagID)
        try container.encodeIfPresent(recurrenceRule, forKey: .recurrenceRule)
        try container.encodeIfPresent(recurrenceSourceID, forKey: .recurrenceSourceID)
        try container.encodeIfPresent(recurrenceOccurrenceDate, forKey: .recurrenceOccurrenceDate)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try container.encodeIfPresent(trashOrigin, forKey: .trashOrigin)
        try container.encodeIfPresent(deletedParentID, forKey: .deletedParentID)
        try container.encode(subtasks, forKey: .subtasks)
    }
}
