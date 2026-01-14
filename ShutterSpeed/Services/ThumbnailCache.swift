import Foundation
import AppKit
import CoreGraphics

actor ThumbnailCache {
    private let libraryURL: URL
    private var memoryCache: [UUID: [ThumbnailSize: NSImage]] = [:]
    private let maxMemoryCacheSize = 500 // Max images in memory

    enum ThumbnailSize: Int, CaseIterable {
        case small = 256
        case medium = 1024
        case large = 2048

        var cgSize: CGSize {
            CGSize(width: rawValue, height: rawValue)
        }
    }

    init(libraryURL: URL) {
        self.libraryURL = libraryURL
    }

    // MARK: - Public API

    func thumbnail(for image: PhotoImage, size: ThumbnailSize) async -> NSImage? {
        // Check memory cache first
        if let cached = memoryCache[image.id]?[size] {
            return cached
        }

        // Check disk cache
        if let diskCached = loadFromDisk(imageID: image.id, size: size) {
            cacheInMemory(image: diskCached, id: image.id, size: size)
            return diskCached
        }

        // Generate on demand
        guard let generated = await generateThumbnail(for: image, size: size) else {
            return nil
        }

        cacheInMemory(image: generated, id: image.id, size: size)
        saveToDisk(image: generated, imageID: image.id, size: size)

        return generated
    }

    func generateThumbnails(for image: PhotoImage) async {
        for size in ThumbnailSize.allCases {
            _ = await thumbnail(for: image, size: size)
        }
    }

    func clearMemoryCache() {
        memoryCache.removeAll()
    }

    // MARK: - Private

    private func generateThumbnail(for image: PhotoImage, size: ThumbnailSize) async -> NSImage? {
        guard let cgSource = CGImageSourceCreateWithURL(image.filePath as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: size.rawValue,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(cgSource, 0, options as CFDictionary) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private func cacheInMemory(image: NSImage, id: UUID, size: ThumbnailSize) {
        if memoryCache[id] == nil {
            memoryCache[id] = [:]
        }
        memoryCache[id]?[size] = image

        // Evict oldest entries if cache is too large
        if memoryCache.count > maxMemoryCacheSize {
            let keysToRemove = Array(memoryCache.keys.prefix(memoryCache.count - maxMemoryCacheSize))
            for key in keysToRemove {
                memoryCache.removeValue(forKey: key)
            }
        }
    }

    private func thumbnailURL(imageID: UUID, size: ThumbnailSize) -> URL {
        let prefix = String(imageID.uuidString.prefix(2))
        return libraryURL
            .appendingPathComponent("Thumbnails")
            .appendingPathComponent(prefix)
            .appendingPathComponent("\(imageID.uuidString).thumb\(size.rawValue)")
    }

    private func loadFromDisk(imageID: UUID, size: ThumbnailSize) -> NSImage? {
        let url = thumbnailURL(imageID: imageID, size: size)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return NSImage(contentsOf: url)
    }

    private func saveToDisk(image: NSImage, imageID: UUID, size: ThumbnailSize) {
        let url = thumbnailURL(imageID: imageID, size: size)

        // Create directory if needed
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Save as JPEG
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            return
        }

        try? jpegData.write(to: url)
    }
}

// MARK: - Thumbnail Provider for SwiftUI

@MainActor
@Observable
class ThumbnailProvider {
    private let cache: ThumbnailCache
    private var loadingTasks: [UUID: Task<Void, Never>] = [:]

    var thumbnails: [UUID: NSImage] = [:]

    init(cache: ThumbnailCache) {
        self.cache = cache
    }

    func loadThumbnail(for image: PhotoImage, size: ThumbnailCache.ThumbnailSize = .medium) {
        guard thumbnails[image.id] == nil, loadingTasks[image.id] == nil else { return }

        loadingTasks[image.id] = Task {
            let thumbnail = await cache.thumbnail(for: image, size: size)
            await MainActor.run {
                self.thumbnails[image.id] = thumbnail
                self.loadingTasks.removeValue(forKey: image.id)
            }
        }
    }

    func cancelLoading(for imageID: UUID) {
        loadingTasks[imageID]?.cancel()
        loadingTasks.removeValue(forKey: imageID)
    }
}
