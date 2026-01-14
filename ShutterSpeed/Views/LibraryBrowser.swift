import SwiftUI

struct LibraryBrowser: View {
    let library: PhotoLibrary
    @Environment(LibraryManager.self) private var libraryManager
    @State private var thumbnailProvider: ThumbnailProvider?
    @State private var selectedTab: SidebarItem = .allPhotos
    @State private var searchText = ""
    @State private var showImportDialog = false
    @State private var currentImage: PhotoImage?
    @State private var showCompare = false
    @State private var compareImages: [PhotoImage] = []

    // Filter state
    @State private var filterCriteria = FilterCriteria()

    // Album dialogs
    @State private var showNewAlbumDialog = false
    @State private var showNewSmartAlbumDialog = false
    @State private var albumToRename: Album?

    var body: some View {
        NavigationSplitView {
            Sidebar(
                selectedTab: $selectedTab,
                albums: library.albums,
                onCreateAlbum: { showNewAlbumDialog = true },
                onCreateSmartAlbum: { showNewSmartAlbumDialog = true },
                onDeleteAlbum: { id in
                    // Delete album from library
                    if let index = library.albums.firstIndex(where: { $0.id == id }) {
                        library.albums.remove(at: index)
                    }
                },
                onRenameAlbum: { id in
                    albumToRename = library.albums.first { $0.id == id }
                }
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            VStack(spacing: 0) {
                // Main Toolbar
                MainToolbar(
                    viewMode: Binding(
                        get: { libraryManager.viewMode },
                        set: { libraryManager.viewMode = $0 }
                    ),
                    gridSize: Binding(
                        get: { libraryManager.gridSize },
                        set: { libraryManager.gridSize = $0 }
                    ),
                    sortOrder: Binding(
                        get: { libraryManager.sortOrder },
                        set: { libraryManager.sortOrder = $0 }
                    ),
                    showFilters: Binding(
                        get: { libraryManager.showFilters },
                        set: { libraryManager.showFilters = $0 }
                    ),
                    showInspector: Binding(
                        get: { libraryManager.showInspector },
                        set: { libraryManager.showInspector = $0 }
                    ),
                    selectedCount: library.selectedImageIDs.count,
                    onImport: { showImportDialog = true },
                    onExport: { libraryManager.showExportDialog = true }
                )

                Divider()

                // Filter bar (conditional)
                if libraryManager.showFilters {
                    FilterBar(
                        criteria: $filterCriteria,
                        isExpanded: .constant(true),
                        resultCount: filteredImages.count,
                        onReset: { filterCriteria = FilterCriteria() }
                    )
                    Divider()
                }

                // Main content area with optional inspector
                HSplitView {
                    // Photo content based on view mode
                    mainContentView

                    // Inspector panel (conditional)
                    if libraryManager.showInspector {
                        InspectorPanel(
                            image: Binding(
                                get: { selectedImages.first },
                                set: { _ in }
                            ),
                            onSaveChanges: { image in
                                // Save changes to database
                            }
                        )
                        .frame(width: 280)
                    }
                }

                Divider()

                // Status bar
                StatusBar(
                    libraryName: library.name,
                    imageCount: library.images.count,
                    selectedCount: library.selectedImageIDs.count,
                    currentImage: currentImage,
                    isLoading: library.isLoading,
                    loadingMessage: nil,
                    diskUsage: nil
                )
            }
        }
        .onAppear {
            thumbnailProvider = ThumbnailProvider(cache: library.thumbnailCache)
        }
        .onChange(of: library.selectedImageIDs) { _, newValue in
            if let firstID = newValue.first {
                currentImage = library.images.first { $0.id == firstID }
            } else {
                currentImage = nil
            }
        }
        .fileImporter(
            isPresented: $showImportDialog,
            allowedContentTypes: [.image, .rawImage],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: Binding(
            get: { libraryManager.showExportDialog },
            set: { libraryManager.showExportDialog = $0 }
        )) {
            ExportDialog(
                images: selectedImages,
                onExport: { settings in
                    Task {
                        await exportImages(with: settings)
                    }
                }
            )
        }
        .sheet(isPresented: $showNewAlbumDialog) {
            NewAlbumDialog { name in
                _ = try? library.createAlbum(name: name)
            }
        }
        .sheet(isPresented: $showNewSmartAlbumDialog) {
            SmartAlbumDialog { name, criteria in
                _ = try? library.createAlbum(name: name, isSmart: true, criteria: criteria)
            }
        }
        .sheet(item: $albumToRename) { album in
            RenameAlbumDialog(originalName: album.name) { newName in
                if let index = library.albums.firstIndex(where: { $0.id == album.id }) {
                    library.albums[index].name = newName
                }
            }
        }
    }

    // MARK: - Main Content View

    @ViewBuilder
    private var mainContentView: some View {
        switch libraryManager.viewMode {
        case .grid:
            gridView
        case .detail:
            detailView
        case .compare:
            compareView
        }
    }

    private var gridView: some View {
        Group {
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
                    gridSize: libraryManager.gridSize,
                    onDoubleClick: { image in
                        currentImage = image
                        libraryManager.viewMode = .detail
                    },
                    onUpdateImage: { id, update in
                        library.updateImage(id: id, update: update)
                    },
                    onDeleteImage: { id in
                        library.deleteImage(id: id)
                    }
                )
            }
        }
    }

    private var detailView: some View {
        Group {
            if let image = currentImage {
                DetailViewer(
                    image: image,
                    allImages: filteredImages,
                    onNavigate: { newImage in
                        currentImage = newImage
                        library.selectedImageIDs = [newImage.id]
                    },
                    onBack: {
                        libraryManager.viewMode = .grid
                    }
                )
            } else if let firstImage = selectedImages.first {
                DetailViewer(
                    image: firstImage,
                    allImages: filteredImages,
                    onNavigate: { newImage in
                        currentImage = newImage
                        library.selectedImageIDs = [newImage.id]
                    },
                    onBack: {
                        libraryManager.viewMode = .grid
                    }
                )
            } else {
                Text("Select a photo to view")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var compareView: some View {
        CompareView(
            images: Array(selectedImages.prefix(4)),
            layout: .sideBySide,
            syncZoom: true,
            syncPan: true
        )
    }

    // MARK: - Selected Images

    private var selectedImages: [PhotoImage] {
        library.images.filter { library.selectedImageIDs.contains($0.id) }
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

        // Apply filter criteria
        images = filterCriteria.apply(to: images)

        // Filter by search
        if !searchText.isEmpty {
            images = images.filter { image in
                image.fileName.localizedCaseInsensitiveContains(searchText) ||
                image.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                image.metadata.cameraModel?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        // Sort
        images = sortImages(images)

        return images
    }

    private func sortImages(_ images: [PhotoImage]) -> [PhotoImage] {
        switch libraryManager.sortOrder {
        case .captureDate:
            return images.sorted { ($0.metadata.captureDate ?? .distantPast) < ($1.metadata.captureDate ?? .distantPast) }
        case .captureDateDescending:
            return images.sorted { ($0.metadata.captureDate ?? .distantPast) > ($1.metadata.captureDate ?? .distantPast) }
        case .importDate:
            return images.sorted { $0.importDate > $1.importDate }
        case .fileName:
            return images.sorted { $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending }
        case .rating:
            return images.sorted { $0.rating > $1.rating }
        case .fileSize:
            return images.sorted { ($0.fileSize ?? 0) > ($1.fileSize ?? 0) }
        }
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

    private func exportImages(with settings: ExportSettings) async {
        let exporter = ExportService()
        for image in selectedImages {
            do {
                let exportURL = settings.destination
                    .appendingPathComponent(image.fileName)
                    .deletingPathExtension()
                    .appendingPathExtension(settings.format.fileExtension)

                _ = try await exporter.export(
                    image: image,
                    to: exportURL,
                    settings: settings
                )
            } catch {
                print("Export failed for \(image.fileName): \(error)")
            }
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
