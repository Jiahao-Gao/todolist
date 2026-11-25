import AppKit
import SwiftUI
import TodoCore

@main
struct TodoListApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(AppTypography.fontNameStorageKey) private var appFontName = AppTypography.defaultFontName
    @StateObject private var store = TodoStore()

    var body: some Scene {
        WindowGroup("Todo List", id: "main") {
            ContentView(store: store)
                .font(AppTypography.body(appFontName))
                .frame(minWidth: 860, minHeight: 560)
        }
        .commands {
            TodoListCommands()
        }

        Settings {
            SettingsView()
                .font(AppTypography.body(appFontName))
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
