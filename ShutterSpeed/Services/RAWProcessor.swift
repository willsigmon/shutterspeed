import Foundation
import CoreImage
import AppKit

/// GPU-accelerated RAW processing using Core Image
final class RAWProcessor {
    static let shared = RAWProcessor()

    private let context: CIContext
    private let colorSpace: CGColorSpace

    // Supported RAW extensions
    static let rawExtensions: Set<String> = [
        "cr2", "cr3",   // Canon
        "nef",          // Nikon
        "arw",          // Sony
        "raf",          // Fujifilm
        "orf",          // Olympus
        "rw2",          // Panasonic
        "dng",          // Adobe DNG
        "raw",          // Generic
        "srw",          // Samsung
        "pef",          // Pentax
        "x3f"           // Sigma
    ]

    private init() {
        // Create Metal-backed context for GPU acceleration
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: metalDevice, options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3)!,
                .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .useSoftwareRenderer: false
            ])
        } else {
            context = CIContext(options: [
                .useSoftwareRenderer: true
            ])
        }

        colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    }

    // MARK: - Public API

    /// Check if a file is a RAW format
    static func isRAWFile(_ url: URL) -> Bool {
        rawExtensions.contains(url.pathExtension.lowercased())
    }

    /// Load and decode a RAW file
    func loadRAW(from url: URL) throws -> CIImage {
        guard let filter = CIFilter(imageURL: url, options: nil) else {
            throw RAWProcessorError.failedToLoadRAW
        }

        // Apply default RAW processing
        filter.setValue(true, forKey: kCIInputEnableVendorLensCorrectionKey)

        guard let outputImage = filter.outputImage else {
            throw RAWProcessorError.failedToDecodeRAW
        }

        return outputImage
    }

    /// Load RAW with custom settings
    func loadRAW(from url: URL, settings: RAWSettings) throws -> CIImage {
        let options: [String: Any] = [
            kCIInputBoostKey: settings.boost,
            kCIInputBoostShadowAmountKey: settings.boostShadow,
            kCIInputNeutralChromaticityXKey: settings.neutralX,
            kCIInputNeutralChromaticityYKey: settings.neutralY,
            kCIInputNeutralTemperatureKey: settings.temperature,
            kCIInputNeutralTintKey: settings.tint,
            kCIInputNoiseReductionAmountKey: settings.noiseReduction,
            kCIInputNoiseReductionSharpnessAmountKey: settings.noiseReductionSharpness,
            kCIInputNoiseReductionContrastAmountKey: settings.noiseReductionContrast,
            kCIInputNoiseReductionDetailAmountKey: settings.noiseReductionDetail,
            kCIInputEnableVendorLensCorrectionKey: settings.enableLensCorrection,
            kCIInputEnableSharpeningKey: settings.enableSharpening,
            kCIInputLinearSpaceFilterKey: settings.linearSpaceFilter,
            kCIInputBaselineExposureKey: settings.baselineExposure
        ]

        guard let filter = CIFilter(imageURL: url, options: options) else {
            throw RAWProcessorError.failedToLoadRAW
        }

        guard let outputImage = filter.outputImage else {
            throw RAWProcessorError.failedToDecodeRAW
        }

        return outputImage
    }

    /// Load any image (RAW or standard)
    func loadImage(from url: URL) throws -> CIImage {
        if Self.isRAWFile(url) {
            return try loadRAW(from: url)
        } else {
            guard let image = CIImage(contentsOf: url) else {
                throw RAWProcessorError.failedToLoadImage
            }
            return image
        }
    }

    /// Generate preview image at specified size
    func generatePreview(from url: URL, maxSize: CGFloat = 2048) throws -> NSImage {
        let ciImage = try loadImage(from: url)

        // Scale down if needed
        let scale = min(maxSize / ciImage.extent.width, maxSize / ciImage.extent.height, 1.0)
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw RAWProcessorError.failedToRenderImage
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Render CIImage to CGImage
    func render(_ ciImage: CIImage) -> CGImage? {
        context.createCGImage(ciImage, from: ciImage.extent)
    }

    /// Render CIImage to NSImage
    func renderToNSImage(_ ciImage: CIImage) -> NSImage? {
        guard let cgImage = render(ciImage) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Get RAW file info
    func getRAWInfo(from url: URL) throws -> RAWInfo {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw RAWProcessorError.failedToLoadRAW
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            throw RAWProcessorError.failedToReadProperties
        }

        let width = properties[kCGImagePropertyPixelWidth as String] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight as String] as? Int ?? 0

        var cameraMake: String?
        var cameraModel: String?

        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            cameraMake = tiff[kCGImagePropertyTIFFMake as String] as? String
            cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String
        }

        return RAWInfo(
            width: width,
            height: height,
            cameraMake: cameraMake,
            cameraModel: cameraModel,
            colorSpace: properties[kCGImagePropertyColorModel as String] as? String
        )
    }
}

// MARK: - Supporting Types

struct RAWSettings {
    var boost: Double = 0.5
    var boostShadow: Double = 0.0
    var neutralX: Double = 0.3127
    var neutralY: Double = 0.3290
    var temperature: Double = 6500
    var tint: Double = 0
    var noiseReduction: Double = 0.5
    var noiseReductionSharpness: Double = 0.5
    var noiseReductionContrast: Double = 0.5
    var noiseReductionDetail: Double = 0.5
    var enableLensCorrection: Bool = true
    var enableSharpening: Bool = true
    var linearSpaceFilter: Bool = false
    var baselineExposure: Double = 0

    static let `default` = RAWSettings()
}

struct RAWInfo {
    let width: Int
    let height: Int
    let cameraMake: String?
    let cameraModel: String?
    let colorSpace: String?

    var megapixels: Double {
        Double(width * height) / 1_000_000
    }

    var aspectRatio: Double {
        guard height > 0 else { return 1.0 }
        return Double(width) / Double(height)
    }
}

// MARK: - Errors

enum RAWProcessorError: LocalizedError {
    case failedToLoadRAW
    case failedToDecodeRAW
    case failedToLoadImage
    case failedToRenderImage
    case failedToReadProperties
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .failedToLoadRAW:
            return "Failed to load RAW file"
        case .failedToDecodeRAW:
            return "Failed to decode RAW data"
        case .failedToLoadImage:
            return "Failed to load image"
        case .failedToRenderImage:
            return "Failed to render image"
        case .failedToReadProperties:
            return "Failed to read image properties"
        case .unsupportedFormat:
            return "Unsupported image format"
        }
    }
}

// MARK: - Core Image Keys (for older SDKs)

private let kCIInputBoostKey = "inputBoost"
private let kCIInputBoostShadowAmountKey = "inputBoostShadowAmount"
private let kCIInputNeutralChromaticityXKey = "inputNeutralChromaticityX"
private let kCIInputNeutralChromaticityYKey = "inputNeutralChromaticityY"
private let kCIInputNeutralTemperatureKey = "inputNeutralTemperature"
private let kCIInputNeutralTintKey = "inputNeutralTint"
private let kCIInputNoiseReductionAmountKey = "inputNoiseReductionAmount"
private let kCIInputNoiseReductionSharpnessAmountKey = "inputNoiseReductionSharpnessAmount"
private let kCIInputNoiseReductionContrastAmountKey = "inputNoiseReductionContrastAmount"
private let kCIInputNoiseReductionDetailAmountKey = "inputNoiseReductionDetailAmount"
private let kCIInputEnableVendorLensCorrectionKey = "inputEnableVendorLensCorrection"
private let kCIInputEnableSharpeningKey = "inputEnableSharpening"
private let kCIInputLinearSpaceFilterKey = "inputLinearSpaceFilter"
private let kCIInputBaselineExposureKey = "inputBaselineExposure"
