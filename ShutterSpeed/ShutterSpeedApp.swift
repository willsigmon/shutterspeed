import SwiftUI

@main
struct ShutterSpeedApp: App {
    @State private var libraryManager = LibraryManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(libraryManager)
        }
        .commands {
            // Core file commands
            CommandGroup(replacing: .newItem) {
                Button("New Library...") {
                    libraryManager.showNewLibraryDialog = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Open Library...") {
                    libraryManager.showOpenLibraryDialog = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(after: .importExport) {
                Button("Import Photos...") {
                    libraryManager.showImportDialog = true
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(libraryManager.currentLibrary == nil)

                Button("Export Selected...") {
                    libraryManager.showExportDialog = true
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(libraryManager.currentLibrary == nil)
            }

            // Full application menu commands
            AppMenuCommands()
        }

        Settings {
            SettingsView()
        }
    }
}
