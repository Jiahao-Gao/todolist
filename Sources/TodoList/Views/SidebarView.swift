import SwiftUI
import TodoCore

struct SidebarView: View {
    @ObservedObject var store: TodoStore
    @Binding var selection: TodoSidebarSelection
    @AppStorage(AppTypography.fontNameStorageKey) private var appFontName = AppTypography.defaultFontName
    @State private var renamingTagID: TodoTag.ID?
    @State private var renamingTagName = ""
    private let countColumnWidth: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            List(selection: sidebarSelection) {
                Group {
                    Text("Todos")
                        .font(AppTypography.small(appFontName).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                        .selectionDisabled()

                    ForEach(TodoFilter.allCases) { filter in
                        HStack(spacing: 8) {
                            Image(systemName: filter.systemImage)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            Text(filter.title)
                                .font(AppTypography.body(appFontName))

                            Spacer()

                            Text("\(store.count(for: filter))")
                                .font(AppTypography.small(appFontName))
                                .foregroundStyle(.secondary)
                                .frame(width: countColumnWidth, alignment: .center)
                        }
                        .tag(TodoSidebarSelection.filter(filter))
                    }
                }

                Group {
                    tagHeading
                        .selectionDisabled()

                    ForEach(store.tags) { tag in
                        HStack(spacing: 8) {
                            TodoTagIcon(color: tag.color, width: 24, height: 18)

                            Text(tag.name)
                                .font(AppTypography.body(appFontName))

                            Spacer()

                            Text("\(store.count(forTag: tag.id))")
                                .font(AppTypography.small(appFontName))
                                .foregroundStyle(.secondary)
                                .frame(width: countColumnWidth, alignment: .center)
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
            .contextMenu {
                Button("clear", role: .destructive) {
                    store.clearTrash(ids: Set(store.trashItems.map(\.id)))
                }
            }
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

    private var tagHeading: some View {
        VStack(spacing: 12) {
            Rectangle()
                .fill(Color.secondary.opacity(0.34))
                .frame(height: 1)

            HStack {
                Text("Tag")
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button {
                    let tag = store.addTag()
                    selection = .tag(tag.id)
                    renamingTagID = tag.id
                    renamingTagName = tag.name
                } label: {
                    Image(systemName: "plus.circle")
                        .frame(width: countColumnWidth, alignment: .center)
                }
                .buttonStyle(.plain)
                .help("New Tag")
            }
            .padding(.bottom, 5)
        }
        .font(AppTypography.small(appFontName).weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.top, 14)
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
                    .frame(width: countColumnWidth, alignment: .center)
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
