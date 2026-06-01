import SwiftUI

struct SettingsView: View {
    @AppStorage(AppTypography.fontNameStorageKey) private var appFontName = AppTypography.defaultFontName

    var body: some View {
        Form {
            Picker("Font", selection: $appFontName) {
                ForEach(AppFontOption.allCases) { option in
                    Text(option.title)
                        .font(AppTypography.body(option.rawValue))
                        .tag(option.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
        .font(AppTypography.body(appFontName))
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 360)
    }
}
