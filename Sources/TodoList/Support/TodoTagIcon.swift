import SwiftUI
import TodoCore

struct TodoTagIcon: View {
    let color: TodoTagColor
    var width: CGFloat = 24
    var height: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(color.swiftUIColor)
            .frame(width: width, height: height)
            .overlay {
                Text("#")
                    .font(.system(size: height * 0.62, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .baselineOffset(1)
            }
            .accessibilityLabel("Tag")
    }
}
