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
            }
        }

        Settings {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            LibrarySettingsView()
                .tabItem {
                    Label("Library", systemImage: "photo.on.rectangle")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Text("General settings coming soon")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct LibrarySettingsView: View {
    var body: some View {
        Form {
            Text("Library settings coming soon")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
