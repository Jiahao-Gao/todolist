import SwiftUI
import TodoCore

extension TodoTagColor {
    var swiftUIColor: Color {
        switch self {
        case .red:
            .red
        case .orange:
            .orange
        case .yellow:
            .yellow
        case .green:
            .green
        case .mint:
            .mint
        case .blue:
            .blue
        case .purple:
            .purple
        case .gray:
            .gray
        }
    }
}
