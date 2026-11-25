import Foundation
import TodoCore

enum TodoSidebarSelection: Hashable {
    case filter(TodoFilter)
    case tag(TodoTag.ID)
    case trash

    init(storageValue: String?) {
        guard let storageValue else {
            self = .filter(.all)
            return
        }

        if storageValue == "trash" {
            self = .trash
            return
        }

        if let filter = TodoFilter(rawValue: storageValue) {
            self = .filter(filter)
            return
        }

        if storageValue.hasPrefix("tag:") {
            let idString = String(storageValue.dropFirst(4))

            if let id = UUID(uuidString: idString) {
                self = .tag(id)
                return
            }
        }

        self = .filter(.all)
    }

    var storageValue: String {
        switch self {
        case let .filter(filter):
            filter.rawValue
        case let .tag(id):
            "tag:\(id.uuidString)"
        case .trash:
            "trash"
        }
    }
}
