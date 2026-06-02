import SwiftUI
import TodoCore

struct SidebarView: View {
    @ObservedObject var store: TodoStore
    @Binding var selection: TodoSidebarSelection
    @AppStorage(AppTypography.fontNameStorageKey) private var appFontName = AppTypography.defaultFontName
    @State private var renamingTagID: TodoTag.ID?
    @State private var renamingTagName = ""

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
                        .tag(TodoSidebarSelection.filter(filter))
                    }
                }

                Section {
                    ForEach(store.tags) { tag in
                        Label {
                            HStack {
                                Text(tag.name)
                                    .font(AppTypography.body(appFontName))

                                Spacer()

                                Text("\(store.count(forTag: tag.id))")
                                    .font(AppTypography.small(appFontName))
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            TodoTagIcon(color: tag.color, width: 24, height: 18)
                        }
                        .tag(TodoSidebarSelection.tag(tag.id))
                        .contextMenu {
                            Button("Change Name") {
                                renamingTagID = tag.id
                                renamingTagName = tag.name
                            }

                            Menu("Change Color") {
                                ForEach(TodoTagColor.allCases, id: \.self) { color in
                                    Button(color.title) {
                                        store.updateTagColor(id: tag.id, color: color)
                                    }
                                }
                            }

                            Button("Delete tag only", role: .destructive) {
                                if selection == .tag(tag.id) {
                                    selection = .filter(.all)
                                }

                                store.deleteTag(id: tag.id)
                            }

                            Button("Delete tag and tasks", role: .destructive) {
                                if selection == .tag(tag.id) {
                                    selection = .filter(.all)
                                }

                                store.deleteTagAndTasks(id: tag.id)
                            }
                        }
                    }
                } header: {
                    VStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.34))
                            .frame(height: 1)

                        HStack {
                            Text("Tag")

                            Spacer()

                            Button {
                                let tag = store.addTag()
                                selection = .tag(tag.id)
                                renamingTagID = tag.id
                                renamingTagName = tag.name
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.plain)
                            .help("New Tag")
                        }
                        .padding(.trailing, 11)
                        .padding(.bottom, 5)
                    }
                    .padding(.top, 14)
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

            Button {
                selection = .trash
            } label: {
                footerSidebarRow(
                    title: "Trash",
                    systemImage: "trash",
                    count: store.trashCount(),
                    isSelected: selection == .trash
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.top, 8)

            SettingsLink {
                footerSidebarRow(
                    title: "Settings",
                    systemImage: "gearshape",
                    count: nil,
                    isSelected: false
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .navigationTitle("Todo List")
        .sheet(isPresented: isRenamingTag) {
            TagRenameSheet(
                name: $renamingTagName,
                saveAction: {
                    if let renamingTagID {
                        store.renameTag(id: renamingTagID, name: renamingTagName)
                    }

                    renamingTagID = nil
                },
                cancelAction: {
                    renamingTagID = nil
                }
            )
            .font(AppTypography.body(appFontName))
        }
    }

    private var sidebarSelection: Binding<TodoSidebarSelection?> {
        Binding {
            selection
        } set: { newValue in
            if let newValue {
                selection = newValue
            }
        }
    }

    private func footerSidebarRow(
        title: String,
        systemImage: String,
        count: Int?,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(title)
                .font(AppTypography.body(appFontName))

            Spacer()

            if let count {
                Text("\(count)")
                    .font(AppTypography.small(appFontName))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
            }
        }
    }

    private var isRenamingTag: Binding<Bool> {
        Binding {
            renamingTagID != nil
        } set: { newValue in
            if !newValue {
                renamingTagID = nil
            }
        }
    }
}

private struct TagRenameSheet: View {
    @Binding var name: String
    let saveAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Change Tag Name")
                .font(.headline)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()

                Button("Cancel", action: cancelAction)

                Button("Save", action: saveAction)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
