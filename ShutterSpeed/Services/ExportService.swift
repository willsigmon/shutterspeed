import Foundation
import CoreImage
import AppKit
import UniformTypeIdentifiers

/// Handles exporting images to various formats
final class ExportService {
    static let shared = ExportService()

    private let editEngine = EditEngine.shared
    private let context: CIContext

    private init() {
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: metalDevice)
        } else {
            context = CIContext()
        }
    }

    // MARK: - Export Settings

    struct ExportSettings {
        var format: ExportFormat = .jpeg
        var quality: Double = 0.9 // 0-1 for lossy formats
        var maxSize: CGSize? = nil // nil = original size
        var colorSpace: CGColorSpace? = nil // nil = sRGB
        var includeMetadata: Bool = true
        var writeXMP: Bool = false
        var namingScheme: NamingScheme = .original
        var subfolder: String? = nil

        enum NamingScheme {
            case original
            case sequential(prefix: String, start: Int)
            case datetime
            case custom((PhotoImage) -> String)
        }
    }

    enum ExportFormat: String, CaseIterable, Identifiable {
        case jpeg = "JPEG"
        case tiff = "TIFF"
        case png = "PNG"
        case heic = "HEIC"

        var id: String { rawValue }

        var utType: UTType {
            switch self {
            case .jpeg: return .jpeg
            case .tiff: return .tiff
            case .png: return .png
            case .heic: return .heic
            }
        }

        var fileExtension: String {
            switch self {
            case .jpeg: return "jpg"
            case .tiff: return "tiff"
            case .png: return "png"
            case .heic: return "heic"
            }
        }

        var supportsQuality: Bool {
            self == .jpeg || self == .heic
        }
    }

    struct ExportResult {
        let exportedFiles: [URL]
        let failedFiles: [(PhotoImage, Error)]
        let duration: TimeInterval
        let totalSize: Int64
    }

    // MARK: - Public API

    /// Export multiple images
    func export(
        images: [PhotoImage],
        edits: [UUID: EditState],
        to destination: URL,
        settings: ExportSettings,
        progress: ((Double, String) -> Void)? = nil
    ) async throws -> ExportResult {
        let startTime = Date()
        var exportedFiles: [URL] = []
        var failedFiles: [(PhotoImage, Error)] = []
        var totalSize: Int64 = 0

        // Create destination folder if needed
        let fm = FileManager.default
        var exportDir = destination
        if let subfolder = settings.subfolder {
            exportDir = destination.appendingPathComponent(subfolder)
        }
        try fm.createDirectory(at: exportDir, withIntermediateDirectories: true)

        for (index, image) in images.enumerated() {
            progress?(Double(index) / Double(images.count), image.fileName)

            do {
                let outputURL = try await exportSingle(
                    image: image,
                    edits: edits[image.id],
                    to: exportDir,
                    settings: settings,
                    index: index
                )
                exportedFiles.append(outputURL)

                if let attrs = try? fm.attributesOfItem(atPath: outputURL.path),
                   let size = attrs[.size] as? Int64 {
                    totalSize += size
                }
            } catch {
                failedFiles.append((image, error))
            }
        }

        progress?(1.0, "Complete")

        return ExportResult(
            exportedFiles: exportedFiles,
            failedFiles: failedFiles,
            duration: Date().timeIntervalSince(startTime),
            totalSize: totalSize
        )
    }

    /// Export single image
    func exportSingle(
        image: PhotoImage,
        edits: EditState?,
        to destination: URL,
        settings: ExportSettings,
        index: Int = 0
    ) async throws -> URL {
        // Load and apply edits
        var ciImage: CIImage
        if let edits = edits, !edits.adjustments.isEmpty {
            ciImage = try editEngine.apply(edits: edits, to: image.filePath)
        } else {
            ciImage = try RAWProcessor.shared.loadImage(from: image.filePath)
        }

        // Resize if needed
        if let maxSize = settings.maxSize {
            let scale = min(
                maxSize.width / ciImage.extent.width,
                maxSize.height / ciImage.extent.height,
                1.0
            )
            if scale < 1.0 {
                ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            }
        }

        // Generate output filename
        let fileName = generateFileName(for: image, settings: settings, index: index)
        let outputURL = destination.appendingPathComponent(fileName)

        // Render to file
        let colorSpace = settings.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!

        switch settings.format {
        case .jpeg:
            try writeJPEG(ciImage, to: outputURL, quality: settings.quality, colorSpace: colorSpace)

        case .tiff:
            try writeTIFF(ciImage, to: outputURL, colorSpace: colorSpace)

        case .png:
            try writePNG(ciImage, to: outputURL, colorSpace: colorSpace)

        case .heic:
            try writeHEIC(ciImage, to: outputURL, quality: settings.quality, colorSpace: colorSpace)
        }

        // Write XMP sidecar if requested
        if settings.writeXMP, let edits = edits {
            let xmpURL = outputURL.deletingPathExtension().appendingPathExtension("xmp")
            try XMPService.shared.writeXMP(edits: edits, metadata: image.metadata, to: xmpURL)
        }

        return outputURL
    }

    // MARK: - Private

    private func generateFileName(for image: PhotoImage, settings: ExportSettings, index: Int) -> String {
        let baseName: String

        switch settings.namingScheme {
        case .original:
            baseName = image.filePath.deletingPathExtension().lastPathComponent

        case .sequential(let prefix, let start):
            baseName = String(format: "%@%04d", prefix, start + index)

        case .datetime:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let date = image.captureDate ?? image.importDate
            baseName = formatter.string(from: date)

        case .custom(let generator):
            baseName = generator(image)
        }

        return "\(baseName).\(settings.format.fileExtension)"
    }

    private func writeJPEG(_ image: CIImage, to url: URL, quality: Double, colorSpace: CGColorSpace) throws {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw ExportError.renderFailed
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ExportError.destinationCreationFailed
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.writeFailed
        }

        try data.write(to: url)
    }

    private func writeTIFF(_ image: CIImage, to url: URL, colorSpace: CGColorSpace) throws {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw ExportError.renderFailed
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.tiff.identifier as CFString, 1, nil) else {
            throw ExportError.destinationCreationFailed
        }

        let options: [CFString: Any] = [
            kCGImagePropertyTIFFCompression: 5 // LZW
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.writeFailed
        }

        try data.write(to: url)
    }

    private func writePNG(_ image: CIImage, to url: URL, colorSpace: CGColorSpace) throws {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw ExportError.renderFailed
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw ExportError.destinationCreationFailed
        }

        CGImageDestinationAddImage(destination, cgImage, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.writeFailed
        }

        try data.write(to: url)
    }

    private func writeHEIC(_ image: CIImage, to url: URL, quality: Double, colorSpace: CGColorSpace) throws {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw ExportError.renderFailed
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.heic" as CFString, 1, nil) else {
            throw ExportError.destinationCreationFailed
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.writeFailed
        }

        try data.write(to: url)
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case renderFailed
    case destinationCreationFailed
    case writeFailed
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Failed to render image"
        case .destinationCreationFailed:
            return "Failed to create export destination"
        case .writeFailed:
            return "Failed to write file"
        case .unsupportedFormat:
            return "Unsupported export format"
        }
    }
}
