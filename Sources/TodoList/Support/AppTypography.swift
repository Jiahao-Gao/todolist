import SwiftUI

enum AppFontOption: String, CaseIterable, Identifiable {
    case monaco = "Monaco"
    case menlo = "Menlo"
    case courierNew = "Courier New"
    case helveticaNeue = "Helvetica Neue"
    case avenirNext = "Avenir Next"
    case georgia = "Georgia"

    var id: String { rawValue }
    var title: String { rawValue }
}

enum AppTypography {
    static let fontNameStorageKey = "appFontName"
    static let defaultFontName = AppFontOption.monaco.rawValue

    static func body(_ fontName: String) -> Font {
        Font.custom(fontName, size: 13)
    }

    static func small(_ fontName: String) -> Font {
        Font.custom(fontName, size: 11)
    }

    static func taskRow(_ fontName: String) -> Font {
        Font.custom(fontName, size: 15)
    }

    static func taskDate(_ fontName: String) -> Font {
        Font.custom(fontName, size: 12)
    }

    static func titleField(_ fontName: String) -> Font {
        body(fontName)
    }

    static func notes(_ fontName: String) -> Font {
        Font.custom(fontName, size: 13)
    }
}
