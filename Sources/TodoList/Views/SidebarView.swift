import SwiftUI
import TodoCore

struct SidebarView: View {
    @ObservedObject var store: TodoStore
    @Binding var selection: TodoFilter
    @AppStorage(AppTypography.fontNameStorageKey) private var appFontName = AppTypography.defaultFontName

    var body: some View {
        VStack(spacing: 0) {
            List(selection: sidebarSelection) {
                Section("Todos") {
                    ForEach(TodoFilter.allCases) { filter in
                        Label {
                            HStack {
                                Text(filter.title)
                                    .font(AppTypography.body(appFontName))

                                Spacer()

                                Text("\(store.count(for: filter))")
                                    .font(AppTypography.small(appFontName))
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: filter.systemImage)
                                .foregroundStyle(.secondary)
                        }
                        .tag(filter)
                    }
                }

                if let errorMessage = store.lastErrorMessage {
                    Section("Storage") {
                        Text(errorMessage)
                            .font(AppTypography.small(appFontName))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(AppTypography.body(appFontName))
            .listStyle(.sidebar)

            Divider()

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .font(AppTypography.body(appFontName))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .navigationTitle("Todo List")
    }

    private var sidebarSelection: Binding<TodoFilter?> {
        Binding {
            selection
        } set: { newValue in
            if let newValue {
                selection = newValue
            }
        }
    }
}
