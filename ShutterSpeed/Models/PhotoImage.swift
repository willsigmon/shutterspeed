import Foundation
import CoreGraphics

struct PhotoImage: Identifiable, Hashable {
    let id: UUID
    var filePath: URL
    var fileName: String
    var fileSize: Int64?
    var fileHash: String?

    // Dimensions
    var width: Int?
    var height: Int?

    // Metadata
    var metadata: ImageMetadata

    // Organization
    var rating: Int = 0 // 0-5 stars
    var flag: Flag = .none
    var colorLabel: ColorLabel = .none
    var keywords: [String] = []

    // Timestamps
    var captureDate: Date?
    var importDate: Date = Date()

    // Edit state
    var currentEditVersion: Int = 0
    var editState: EditState = EditState()

    init(
        id: UUID = UUID(),
        filePath: URL,
        fileName: String,
        metadata: ImageMetadata = ImageMetadata()
    ) {
        self.id = id
        self.filePath = filePath
        self.fileName = fileName
        self.metadata = metadata
        self.captureDate = metadata.captureDate
        self.width = metadata.width
        self.height = metadata.height
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PhotoImage, rhs: PhotoImage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Supporting Types

enum Flag: Int, Codable {
    case none = 0
    case pick = 1
    case reject = -1

    var systemImage: String {
        switch self {
        case .none: return "flag"
        case .pick: return "flag.fill"
        case .reject: return "xmark.circle.fill"
        }
    }
}

enum ColorLabel: Int, Codable, CaseIterable {
    case none = 0
    case red = 1
    case orange = 2
    case yellow = 3
    case green = 4
    case blue = 5
    case purple = 6

    var color: Color {
        switch self {
        case .none: return .clear
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        }
    }

    var name: String {
        switch self {
        case .none: return "None"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        }
    }
}

import SwiftUI

extension Color {
    // For color labels
}

// MARK: - Metadata

struct ImageMetadata: Hashable {
    var captureDate: Date?
    var width: Int?
    var height: Int?
    var pixelWidth: Int? { width }  // Alias for StatusBar compatibility
    var pixelHeight: Int? { height } // Alias for StatusBar compatibility

    // Camera info
    var cameraMake: String?
    var cameraModel: String?
    var lensModel: String?

    // Exposure
    var iso: Int?
    var aperture: Double?
    var shutterSpeed: String?
    var focalLength: Double?

    // Location
    var gpsLatitude: Double?
    var gpsLongitude: Double?

    // Other
    var orientation: Int?
    var colorSpace: String?
}

// MARK: - Metadata Extractor

enum ImageMetadataExtractor {
    static func extract(from url: URL) async throws -> ImageMetadata {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw MetadataError.failedToCreateSource
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return ImageMetadata()
        }

        var metadata = ImageMetadata()

        // Basic properties
        metadata.width = properties[kCGImagePropertyPixelWidth as String] as? Int
        metadata.height = properties[kCGImagePropertyPixelHeight as String] as? Int
        metadata.orientation = properties[kCGImagePropertyOrientation as String] as? Int
        metadata.colorSpace = properties[kCGImagePropertyColorModel as String] as? String

        // EXIF data
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            metadata.iso = (exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int])?.first
            metadata.aperture = exif[kCGImagePropertyExifFNumber as String] as? Double
            metadata.focalLength = exif[kCGImagePropertyExifFocalLength as String] as? Double

            if let exposureTime = exif[kCGImagePropertyExifExposureTime as String] as? Double {
                metadata.shutterSpeed = formatShutterSpeed(exposureTime)
            }

            if let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                metadata.captureDate = parseExifDate(dateString)
            }
        }

        // TIFF data (camera info)
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            metadata.cameraMake = tiff[kCGImagePropertyTIFFMake as String] as? String
            metadata.cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String
        }

        // EXIF Aux (lens info)
        if let exifAux = properties[kCGImagePropertyExifAuxDictionary as String] as? [String: Any] {
            metadata.lensModel = exifAux[kCGImagePropertyExifAuxLensModel as String] as? String
        }

        // GPS data
        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
               let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String {
                metadata.gpsLatitude = latRef == "S" ? -lat : lat
            }
            if let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double,
               let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String {
                metadata.gpsLongitude = lonRef == "W" ? -lon : lon
            }
        }

        return metadata
    }

    private static func formatShutterSpeed(_ seconds: Double) -> String {
        if seconds >= 1 {
            return String(format: "%.1f\"", seconds)
        } else {
            let denominator = Int(round(1.0 / seconds))
            return "1/\(denominator)"
        }
    }

    private static func parseExifDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: string)
    }
}

enum MetadataError: Error {
    case failedToCreateSource
}
