import SwiftUI

struct LibraryBrowser: View {
    let library: PhotoLibrary
    @State private var thumbnailProvider: ThumbnailProvider?
    @State private var selectedTab: SidebarItem = .allPhotos
    @State private var searchText = ""
    @State private var gridSize: Double = 150
    @State private var showImportDialog = false

    var body: some View {
        NavigationSplitView {
            Sidebar(
                selectedTab: $selectedTab,
                albums: library.albums
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            VStack(spacing: 0) {
                // Toolbar
                BrowserToolbar(
                    searchText: $searchText,
                    gridSize: $gridSize,
                    selectedCount: library.selectedImageIDs.count,
                    onImport: { showImportDialog = true }
                )

                Divider()

                // Photo Grid
                if library.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredImages.isEmpty {
                    EmptyLibraryView(onImport: { showImportDialog = true })
                } else {
                    PhotoGrid(
                        images: filteredImages,
                        selectedIDs: Binding(
                            get: { library.selectedImageIDs },
                            set: { library.selectedImageIDs = $0 }
                        ),
                        thumbnailProvider: thumbnailProvider,
                        gridSize: gridSize
                    )
                }
            }
        }
        .onAppear {
            thumbnailProvider = ThumbnailProvider(cache: library.thumbnailCache)
        }
        .fileImporter(
            isPresented: $showImportDialog,
            allowedContentTypes: [.image, .rawImage],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
    }

    private var filteredImages: [PhotoImage] {
        var images = library.images

        // Filter by sidebar selection
        switch selectedTab {
        case .allPhotos:
            break
        case .recentImports:
            let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            images = images.filter { $0.importDate > oneWeekAgo }
        case .flagged:
            images = images.filter { $0.flag == .pick }
        case .rejected:
            images = images.filter { $0.flag == .reject }
        case .album(let id):
            if let album = library.albums.first(where: { $0.id == id }) {
                images = images.filter { album.imageIDs.contains($0.id) }
            }
        }

        // Filter by search
        if !searchText.isEmpty {
            images = images.filter { image in
                image.fileName.localizedCaseInsensitiveContains(searchText) ||
                image.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                image.metadata.cameraModel?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        return images
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                try? await library.importImages(from: urls)
            }
        case .failure(let error):
            print("Import failed: \(error)")
        }
    }
}

// MARK: - Toolbar

struct BrowserToolbar: View {
    @Binding var searchText: String
    @Binding var gridSize: Double
    let selectedCount: Int
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Import button
            Button(action: onImport) {
                Label("Import", systemImage: "square.and.arrow.down")
            }

            Divider()
                .frame(height: 20)

            // View options
            HStack(spacing: 4) {
                Button(action: {}) {
                    Image(systemName: "square.grid.2x2")
                }
                .buttonStyle(.borderless)

                Button(action: {}) {
                    Image(systemName: "list.bullet")
                }
                .buttonStyle(.borderless)
            }

            // Grid size slider
            HStack(spacing: 4) {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(value: $gridSize, in: 80...300)
                    .frame(width: 100)

                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Selection count
            if selectedCount > 0 {
                Text("\(selectedCount) selected")
                    .foregroundStyle(.secondary)
            }

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 150)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(6)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

// MARK: - Empty State

struct EmptyLibraryView: View {
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Photos Yet")
                .font(.title2)
                .fontWeight(.medium)

            Text("Import photos to get started")
                .foregroundStyle(.secondary)

            Button("Import Photos") {
                onImport()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LibraryBrowser(library: PhotoLibrary.preview)
}

extension PhotoLibrary {
    static var preview: PhotoLibrary {
        // Create a mock library for previews
        let url = URL(fileURLWithPath: "/tmp/preview.shutterspeed")
        let db = try! Database(url: URL(fileURLWithPath: "/tmp/preview.sqlite"))
        try? db.initialize()
        return PhotoLibrary(url: url, name: "Preview", database: db)
    }

    // Make internal init accessible for preview
    convenience init(url: URL, name: String, database: Database) {
        self.init(url: url, name: name, database: database)
    }
}
