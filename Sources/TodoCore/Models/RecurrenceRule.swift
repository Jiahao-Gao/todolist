import Foundation

public struct RecurrenceRule: Codable, Equatable, Sendable {
    public var frequency: RecurrenceFrequency
    public var weekday: Int?
    public var dayOfMonth: Int?
    public var occurrenceLimit: Int?

    public init(
        frequency: RecurrenceFrequency,
        weekday: Int? = nil,
        dayOfMonth: Int? = nil,
        occurrenceLimit: Int? = nil
    ) {
        self.frequency = frequency
        self.weekday = weekday
        self.dayOfMonth = dayOfMonth
        self.occurrenceLimit = occurrenceLimit
    }

    public static func daily() -> RecurrenceRule {
        RecurrenceRule(frequency: .daily)
    }

    public func occurs(
        on date: Date,
        starting startDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let occurrenceNumber = occurrenceNumber(
            on: date,
            starting: startDate,
            calendar: calendar
        ) else {
            return false
        }

        if let occurrenceLimit {
            return occurrenceNumber <= occurrenceLimit
        }

        return true
    }

    public func occurrenceNumber(
        on date: Date,
        starting startDate: Date,
        calendar: Calendar = .current
    ) -> Int? {
        let startDay = calendar.startOfDay(for: startDate)
        let targetDay = calendar.startOfDay(for: date)

        guard targetDay >= startDay else {
            return nil
        }

        switch frequency {
        case .daily:
            guard let days = calendar.dateComponents([.day], from: startDay, to: targetDay).day else {
                return nil
            }

            return days + 1
        case .weekly:
            let desiredWeekday = weekday ?? calendar.component(.weekday, from: startDay)

            guard calendar.component(.weekday, from: targetDay) == desiredWeekday,
                  let weeks = calendar.dateComponents([.weekOfYear], from: startDay, to: targetDay).weekOfYear else {
                return nil
            }

            return weeks + 1
        case .monthly:
            let desiredDay = dayOfMonth ?? calendar.component(.day, from: startDay)

            guard calendar.component(.day, from: targetDay) == desiredDay else {
                return nil
            }

            let components = calendar.dateComponents([.month], from: startDay, to: targetDay)
            guard let months = components.month else {
                return nil
            }

            return months + 1
        }
    }
}

public enum RecurrenceFrequency: String, CaseIterable, Codable, Equatable, Sendable {
    case daily
    case weekly
    case monthly

    public var title: String {
        switch self {
        case .daily:
            "Daily"
        case .weekly:
            "Weekly"
        case .monthly:
            "Monthly"
        }
    }
}
