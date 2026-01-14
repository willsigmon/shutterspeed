import SwiftUI

struct ContentView: View {
    @Environment(LibraryManager.self) private var libraryManager

    var body: some View {
        Group {
            if let library = libraryManager.currentLibrary {
                LibraryBrowser(library: library)
            } else {
                WelcomeView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: Binding(
            get: { libraryManager.showNewLibraryDialog },
            set: { libraryManager.showNewLibraryDialog = $0 }
        )) {
            NewLibrarySheet()
        }
        .fileImporter(
            isPresented: Binding(
                get: { libraryManager.showOpenLibraryDialog },
                set: { libraryManager.showOpenLibraryDialog = $0 }
            ),
            allowedContentTypes: [.photoLibrary],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await libraryManager.openLibrary(at: url)
                    }
                }
            case .failure(let error):
                print("Failed to open library: \(error)")
            }
        }
    }
}

struct WelcomeView: View {
    @Environment(LibraryManager.self) private var libraryManager

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            Text("ShutterSpeed")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Create a new library or open an existing one to get started.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("New Library") {
                    libraryManager.showNewLibraryDialog = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Open Library") {
                    libraryManager.showOpenLibraryDialog = true
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(40)
    }
}

struct NewLibrarySheet: View {
    @Environment(LibraryManager.self) private var libraryManager
    @Environment(\.dismiss) private var dismiss

    @State private var libraryName = "My Photos"
    @State private var selectedLocation: URL?
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Library")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Library Name:", text: $libraryName)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Location:")
                    Text(selectedLocation?.path ?? "~/Pictures")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose...") {
                        selectLocation()
                    }
                }
            }
            .formStyle(.grouped)

            if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    createLibrary()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(libraryName.isEmpty || isCreating)
            }
        }
        .padding(24)
        .frame(width: 450)
    }

    private func selectLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose where to save your library"

        if panel.runModal() == .OK {
            selectedLocation = panel.url
        }
    }

    private func createLibrary() {
        isCreating = true
        error = nil

        let baseURL = selectedLocation ?? FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let libraryURL = baseURL.appendingPathComponent("\(libraryName).shutterspeed")

        Task {
            do {
                try await libraryManager.createLibrary(at: libraryURL, name: libraryName)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isCreating = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(LibraryManager())
}
