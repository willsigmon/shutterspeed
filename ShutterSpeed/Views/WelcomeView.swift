import SwiftUI

/// Welcome screen shown on first launch or when no library is open
struct WelcomeView: View {
    @State private var recentLibraries: [RecentLibrary] = []
    @State private var showingCreateSheet = false
    @State private var showingOpenPanel = false

    let onOpenLibrary: (URL) -> Void
    let onCreateLibrary: (String, URL) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Left panel - App info
            leftPanel
                .frame(width: 300)
                .background(
                    LinearGradient(
                        colors: [.accentColor.opacity(0.8), .accentColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Right panel - Recent libraries
            rightPanel
                .frame(maxWidth: .infinity)
                .background(.background)
        }
        .frame(minWidth: 700, minHeight: 450)
        .onAppear {
            loadRecentLibraries()
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateLibrarySheet(onCreate: onCreateLibrary)
        }
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon
            Image(systemName: "camera.aperture")
                .font(.system(size: 80))
                .foregroundStyle(.white)

            // App name
            VStack(spacing: 4) {
                Text("ShutterSpeed")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("Professional Photo Management")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            // Version info
            VStack(spacing: 4) {
                Text("Version 1.0")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                Text("Built with SwiftUI")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            Text("Get Started")
                .font(.title)
                .fontWeight(.semibold)
                .padding(.top, 32)
                .padding(.horizontal, 32)

            // Actions
            VStack(spacing: 12) {
                WelcomeButton(
                    icon: "plus.rectangle.on.folder",
                    title: "Create New Library",
                    subtitle: "Start a new photo library"
                ) {
                    showingCreateSheet = true
                }

                WelcomeButton(
                    icon: "folder",
                    title: "Open Library",
                    subtitle: "Open an existing library"
                ) {
                    openLibraryPanel()
                }

                WelcomeButton(
                    icon: "square.and.arrow.down",
                    title: "Import Photos",
                    subtitle: "Import photos to a new library"
                ) {
                    showingCreateSheet = true
                }
            }
            .padding(.horizontal, 32)

            // Recent libraries
            if !recentLibraries.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Libraries")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    ForEach(recentLibraries) { library in
                        RecentLibraryRow(library: library) {
                            onOpenLibrary(library.url)
                        }
                    }
                }
                .padding(.horizontal, 32)
            }

            Spacer()

            // Help link
            HStack {
                Spacer()
                Button("Learn More About ShutterSpeed") {
                    // TODO: Open help
                }
                .buttonStyle(.link)
                Spacer()
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Actions

    private func loadRecentLibraries() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "recentLibraries"),
           let libraries = try? JSONDecoder().decode([RecentLibrary].self, from: data) {
            recentLibraries = libraries.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        }
    }

    private func openLibraryPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.init(filenameExtension: "shutterspeed")!]
        panel.message = "Select a ShutterSpeed library"

        if panel.runModal() == .OK, let url = panel.url {
            onOpenLibrary(url)
        }
    }
}

// MARK: - Welcome Button

struct WelcomeButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .frame(width: 40)
                    .foregroundStyle(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Recent Library Row

struct RecentLibraryRow: View {
    let library: RecentLibrary
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2)
                    .foregroundStyle(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(library.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(library.url.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                Spacer()

                Text(library.lastOpened.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Create Library Sheet

struct CreateLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var libraryName = "My Photo Library"
    @State private var selectedLocation: URL?

    let onCreate: (String, URL) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Library")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Library Name", text: $libraryName)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    if let location = selectedLocation {
                        Text(location.path)
                            .lineLimit(1)
                            .truncationMode(.head)
                    } else {
                        Text("No location selected")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Choose...") {
                        chooseLocation()
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    if let location = selectedLocation {
                        let libraryURL = location.appendingPathComponent("\(libraryName).shutterspeed")
                        onCreate(libraryName, libraryURL)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(libraryName.isEmpty || selectedLocation == nil)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            // Default to Documents folder
            selectedLocation = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        }
    }

    private func chooseLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose location for your library"

        if panel.runModal() == .OK {
            selectedLocation = panel.url
        }
    }
}

// MARK: - Recent Library Model

struct RecentLibrary: Identifiable, Codable {
    let id: UUID
    let name: String
    let url: URL
    let lastOpened: Date
    let imageCount: Int

    init(name: String, url: URL, imageCount: Int = 0) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.lastOpened = Date()
        self.imageCount = imageCount
    }
}

#Preview {
    WelcomeView(
        onOpenLibrary: { _ in },
        onCreateLibrary: { _, _ in }
    )
}
