import Foundation
import SwiftUI

@Observable
final class PhotoLibrary {
    let url: URL
    let name: String
    private(set) var database: Database
    private(set) var thumbnailCache: ThumbnailCache

    var images: [PhotoImage] = []
    var albums: [Album] = []
    var selectedImageIDs: Set<UUID> = []
    var isLoading = false

    private init(url: URL, name: String, database: Database) {
        self.url = url
        self.name = name
        self.database = database
        self.thumbnailCache = ThumbnailCache(libraryURL: url)
    }

    // MARK: - Library Creation

    static func create(at url: URL, name: String) async throws -> PhotoLibrary {
        let fm = FileManager.default

        // Create bundle structure
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        try fm.createDirectory(at: url.appendingPathComponent("Thumbnails"), withIntermediateDirectories: true)
        try fm.createDirectory(at: url.appendingPathComponent("Previews"), withIntermediateDirectories: true)
        try fm.createDirectory(at: url.appendingPathComponent("Originals"), withIntermediateDirectories: true)
        try fm.createDirectory(at: url.appendingPathComponent("Sidecars"), withIntermediateDirectories: true)

        // Create database
        let dbURL = url.appendingPathComponent("Library.sqlite")
        let database = try Database(url: dbURL)
        try database.initialize()
        try database.insertLibrary(id: UUID(), name: name)

        return PhotoLibrary(url: url, name: name, database: database)
    }

    static func open(at url: URL) async throws -> PhotoLibrary {
        let dbURL = url.appendingPathComponent("Library.sqlite")
        let database = try Database(url: dbURL)

        // Get library name from database
        let name = try database.getLibraryName() ?? url.deletingPathExtension().lastPathComponent

        let library = PhotoLibrary(url: url, name: name, database: database)
        await library.loadImages()
        await library.loadAlbums()

        return library
    }

    // MARK: - Image Management

    func loadImages() async {
        await MainActor.run { isLoading = true }

        do {
            let loadedImages = try database.fetchAllImages()
            await MainActor.run {
                self.images = loadedImages
                self.isLoading = false
            }
        } catch {
            print("Failed to load images: \(error)")
            await MainActor.run { isLoading = false }
        }
    }

    func importImages(from urls: [URL], copyToLibrary: Bool = true) async throws {
        await MainActor.run { isLoading = true }

        for sourceURL in urls {
            do {
                let image = try await importSingleImage(from: sourceURL, copyToLibrary: copyToLibrary)
                await MainActor.run {
                    self.images.append(image)
                }
            } catch {
                print("Failed to import \(sourceURL.lastPathComponent): \(error)")
            }
        }

        await MainActor.run { isLoading = false }
    }

    private func importSingleImage(from sourceURL: URL, copyToLibrary: Bool) async throws -> PhotoImage {
        let id = UUID()
        var filePath = sourceURL

        if copyToLibrary {
            // Organize by date: Originals/2026/01/14/
            let date = Date()
            let calendar = Calendar.current
            let year = String(calendar.component(.year, from: date))
            let month = String(format: "%02d", calendar.component(.month, from: date))
            let day = String(format: "%02d", calendar.component(.day, from: date))

            let destDir = url
                .appendingPathComponent("Originals")
                .appendingPathComponent(year)
                .appendingPathComponent(month)
                .appendingPathComponent(day)

            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

            let destURL = destDir.appendingPathComponent(sourceURL.lastPathComponent)
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            filePath = destURL
        }

        // Extract metadata
        let metadata = try await ImageMetadataExtractor.extract(from: filePath)

        // Create image record
        let image = PhotoImage(
            id: id,
            filePath: filePath,
            fileName: filePath.lastPathComponent,
            metadata: metadata
        )

        // Save to database
        try database.insertImage(image)

        // Generate thumbnails in background
        Task {
            await thumbnailCache.generateThumbnails(for: image)
        }

        return image
    }

    // MARK: - Image Updates

    func updateImage(id: UUID, update: (inout PhotoImage) -> Void) {
        if let index = images.firstIndex(where: { $0.id == id }) {
            update(&images[index])
            // Persist to database
            Task {
                do {
                    try database.updateImage(images[index])
                } catch {
                    print("Failed to update image: \(error)")
                }
            }
        }
    }

    func deleteImage(id: UUID) {
        if let index = images.firstIndex(where: { $0.id == id }) {
            let image = images[index]
            images.remove(at: index)
            selectedImageIDs.remove(id)

            // Delete from database and optionally remove files
            Task {
                do {
                    try database.deleteImage(id: id)
                    // Note: Not deleting the actual file - that could be done with a "move to trash" option
                } catch {
                    print("Failed to delete image from database: \(error)")
                }
            }

            // Remove from any albums
            for i in albums.indices {
                albums[i].imageIDs.removeAll { $0 == id }
            }
        }
    }

    func deleteImages(ids: Set<UUID>) {
        for id in ids {
            deleteImage(id: id)
        }
    }

    // MARK: - Album Management

    func loadAlbums() async {
        do {
            let loadedAlbums = try database.fetchAllAlbums()
            await MainActor.run {
                self.albums = loadedAlbums
            }
        } catch {
            print("Failed to load albums: \(error)")
        }
    }

    func createAlbum(name: String, isSmart: Bool = false, criteria: SmartAlbumCriteria? = nil) throws -> Album {
        let album = Album(
            id: UUID(),
            name: name,
            isSmart: isSmart,
            smartCriteria: criteria
        )
        try database.insertAlbum(album)
        albums.append(album)
        return album
    }

    // MARK: - Lifecycle

    func close() {
        database.close()
    }
}

// MARK: - Supporting Types

struct Album: Identifiable {
    let id: UUID
    var name: String
    var parentID: UUID?
    var isSmart: Bool
    var smartCriteria: SmartAlbumCriteria?
    var imageIDs: [UUID] = []
    var createdAt: Date = Date()
}

struct SmartAlbumCriteria: Codable {
    var rules: [SmartAlbumRule] = []
    var matchAll: Bool = true // AND vs OR
}

struct SmartAlbumRule: Codable {
    var field: SmartAlbumField
    var comparison: SmartAlbumComparison
    var value: String
}

enum SmartAlbumField: String, Codable, CaseIterable {
    case rating
    case flag
    case keyword
    case camera
    case lens
    case captureDate
    case importDate
    case fileName
}

enum SmartAlbumComparison: String, Codable, CaseIterable {
    case equals
    case notEquals
    case contains
    case greaterThan
    case lessThan
    case between
}
