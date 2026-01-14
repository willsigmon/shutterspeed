import Foundation
import AppKit
import UniformTypeIdentifiers

/// Handles importing photos from various sources with progress tracking
@Observable
final class ImportService {
    var isImporting = false
    var progress: Double = 0
    var currentFile: String = ""
    var importedCount = 0
    var failedCount = 0
    var errors: [ImportError] = []

    private let supportedTypes: Set<String> = [
        // RAW formats
        "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2", "dng", "raw", "srw", "pef", "x3f",
        // Standard formats
        "jpg", "jpeg", "png", "tiff", "tif", "heic", "heif", "webp", "gif", "bmp"
    ]

    struct ImportError: Identifiable {
        let id = UUID()
        let fileName: String
        let error: String
    }

    struct ImportResult {
        let imported: [PhotoImage]
        let failed: [ImportError]
        let duration: TimeInterval
    }

    // MARK: - Public API

    /// Import photos from URLs (files or folders)
    func importPhotos(
        from urls: [URL],
        to library: PhotoLibrary,
        copyToLibrary: Bool = true
    ) async -> ImportResult {
        let startTime = Date()
        await MainActor.run {
            isImporting = true
            progress = 0
            importedCount = 0
            failedCount = 0
            errors = []
        }

        // Expand folders and filter to supported files
        let allFiles = expandAndFilter(urls: urls)
        let totalCount = allFiles.count

        var imported: [PhotoImage] = []

        for (index, fileURL) in allFiles.enumerated() {
            await MainActor.run {
                currentFile = fileURL.lastPathComponent
                progress = Double(index) / Double(totalCount)
            }

            do {
                let image = try await importSingleFile(
                    from: fileURL,
                    to: library,
                    copyToLibrary: copyToLibrary
                )
                imported.append(image)
                await MainActor.run {
                    importedCount += 1
                }
            } catch {
                await MainActor.run {
                    failedCount += 1
                    errors.append(ImportError(
                        fileName: fileURL.lastPathComponent,
                        error: error.localizedDescription
                    ))
                }
            }
        }

        await MainActor.run {
            isImporting = false
            progress = 1.0
            currentFile = ""
        }

        return ImportResult(
            imported: imported,
            failed: errors,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    /// Import from Apple Photos app
    func importFromPhotosApp(to library: PhotoLibrary) async throws -> ImportResult {
        // Use PhotoKit to access Photos library
        // For now, open a picker that shows Photos
        throw ImportServiceError.notImplemented("Photos app import coming in Phase 2")
    }

    /// Import from connected camera
    func importFromCamera(to library: PhotoLibrary) async throws -> ImportResult {
        // Use ImageCaptureCore framework
        throw ImportServiceError.notImplemented("Camera import coming in Phase 2")
    }

    // MARK: - Private

    private func expandAndFilter(urls: [URL]) -> [URL] {
        var result: [URL] = []
        let fm = FileManager.default

        for url in urls {
            var isDirectory: ObjCBool = false

            guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                // Recursively enumerate directory
                if let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for case let fileURL as URL in enumerator {
                        if isSupportedFile(fileURL) {
                            result.append(fileURL)
                        }
                    }
                }
            } else {
                if isSupportedFile(url) {
                    result.append(url)
                }
            }
        }

        return result.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func isSupportedFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return supportedTypes.contains(ext)
    }

    private func importSingleFile(
        from sourceURL: URL,
        to library: PhotoLibrary,
        copyToLibrary: Bool
    ) async throws -> PhotoImage {
        let id = UUID()
        var filePath = sourceURL

        // Get file attributes
        let attrs = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let fileSize = attrs[.size] as? Int64

        if copyToLibrary {
            filePath = try copyFileToLibrary(sourceURL, library: library)
        }

        // Extract metadata
        let metadata = try await ImageMetadataExtractor.extract(from: filePath)

        // Compute file hash for deduplication
        let fileHash = try await computeFileHash(filePath)

        // Create image record
        var image = PhotoImage(
            id: id,
            filePath: filePath,
            fileName: filePath.lastPathComponent,
            metadata: metadata
        )
        image.fileSize = fileSize
        image.fileHash = fileHash

        // Save to database
        try library.database.insertImage(image)

        // Queue thumbnail generation
        Task.detached(priority: .utility) {
            await library.thumbnailCache.generateThumbnails(for: image)
        }

        return image
    }

    private func copyFileToLibrary(_ sourceURL: URL, library: PhotoLibrary) throws -> URL {
        let fm = FileManager.default

        // Organize by capture date or current date
        let date: Date
        if let captureDate = try? ImageMetadataExtractor.extractCaptureDate(from: sourceURL) {
            date = captureDate
        } else {
            date = Date()
        }

        let calendar = Calendar.current
        let year = String(calendar.component(.year, from: date))
        let month = String(format: "%02d", calendar.component(.month, from: date))
        let day = String(format: "%02d", calendar.component(.day, from: date))

        let destDir = library.url
            .appendingPathComponent("Originals")
            .appendingPathComponent(year)
            .appendingPathComponent(month)
            .appendingPathComponent(day)

        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        // Handle duplicate filenames
        var destURL = destDir.appendingPathComponent(sourceURL.lastPathComponent)
        var counter = 1

        while fm.fileExists(atPath: destURL.path) {
            let baseName = sourceURL.deletingPathExtension().lastPathComponent
            let ext = sourceURL.pathExtension
            destURL = destDir.appendingPathComponent("\(baseName)_\(counter).\(ext)")
            counter += 1
        }

        try fm.copyItem(at: sourceURL, to: destURL)

        return destURL
    }

    private func computeFileHash(_ url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        // Use first 64KB + last 64KB + file size for fast pseudo-hash
        let chunkSize = 64 * 1024

        var hashData = Data()
        hashData.append(contentsOf: data.prefix(chunkSize))
        if data.count > chunkSize * 2 {
            hashData.append(contentsOf: data.suffix(chunkSize))
        }

        // Simple hash using built-in hasher
        var hasher = Hasher()
        hasher.combine(hashData)
        hasher.combine(data.count)

        return String(format: "%016llx", UInt64(bitPattern: Int64(hasher.finalize())))
    }
}

// MARK: - Errors

enum ImportServiceError: LocalizedError {
    case notImplemented(String)
    case fileNotFound(URL)
    case unsupportedFormat(String)
    case copyFailed(String)

    var errorDescription: String? {
        switch self {
        case .notImplemented(let feature):
            return "\(feature)"
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format)"
        case .copyFailed(let reason):
            return "Failed to copy file: \(reason)"
        }
    }
}

// MARK: - Quick Date Extraction

extension ImageMetadataExtractor {
    static func extractCaptureDate(from url: URL) throws -> Date? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }
}
