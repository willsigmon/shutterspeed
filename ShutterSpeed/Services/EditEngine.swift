import Foundation
import CoreImage
import AppKit

/// Applies non-destructive edits using Core Image filter chains
final class EditEngine {
    static let shared = EditEngine()

    private let context: CIContext
    private let rawProcessor = RAWProcessor.shared

    private init() {
        // Metal-backed context for GPU acceleration
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: metalDevice, options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3)!,
                .cacheIntermediates: true
            ])
        } else {
            context = CIContext()
        }
    }

    // MARK: - Public API

    /// Apply edit state to an image
    func apply(edits: EditState, to imageURL: URL) throws -> CIImage {
        var image = try rawProcessor.loadImage(from: imageURL)

        for adjustment in edits.adjustments where adjustment.enabled {
            image = apply(adjustment: adjustment, to: image)
        }

        return image
    }

    /// Apply a single adjustment
    func apply(adjustment: Adjustment, to image: CIImage) -> CIImage {
        switch adjustment.type {
        case .exposure:
            return applyExposure(image, value: adjustment.parameters["value"] ?? 0)

        case .contrast:
            return applyContrast(image, value: adjustment.parameters["value"] ?? 0)

        case .highlights:
            return applyHighlights(image, value: adjustment.parameters["value"] ?? 0)

        case .shadows:
            return applyShadows(image, value: adjustment.parameters["value"] ?? 0)

        case .whites:
            return applyWhites(image, value: adjustment.parameters["value"] ?? 0)

        case .blacks:
            return applyBlacks(image, value: adjustment.parameters["value"] ?? 0)

        case .temperature:
            return applyTemperature(image, value: adjustment.parameters["value"] ?? 6500)

        case .tint:
            return applyTint(image, value: adjustment.parameters["value"] ?? 0)

        case .saturation:
            return applySaturation(image, value: adjustment.parameters["value"] ?? 0)

        case .vibrance:
            return applyVibrance(image, value: adjustment.parameters["value"] ?? 0)

        case .sharpening:
            return applySharpening(
                image,
                amount: adjustment.parameters["amount"] ?? 0,
                radius: adjustment.parameters["radius"] ?? 1.0
            )

        case .noiseReduction:
            return applyNoiseReduction(
                image,
                luminance: adjustment.parameters["luminance"] ?? 0,
                color: adjustment.parameters["color"] ?? 0
            )

        case .vignette:
            return applyVignette(
                image,
                amount: adjustment.parameters["amount"] ?? 0,
                radius: adjustment.parameters["midpoint"] ?? 50
            )

        case .crop:
            return applyCrop(
                image,
                top: adjustment.parameters["top"] ?? 0,
                left: adjustment.parameters["left"] ?? 0,
                bottom: adjustment.parameters["bottom"] ?? 1,
                right: adjustment.parameters["right"] ?? 1
            )

        case .rotate:
            return applyRotation(image, angle: adjustment.parameters["angle"] ?? 0)

        case .straighten:
            return applyRotation(image, angle: adjustment.parameters["angle"] ?? 0)

        case .curves, .hue, .distortion, .chromaticAberration, .brush, .gradient, .radial:
            // TODO: Implement in Phase 2
            return image
        }
    }

    /// Render to NSImage
    func render(_ ciImage: CIImage, size: CGSize? = nil) -> NSImage? {
        var outputImage = ciImage

        if let size = size {
            let scale = min(size.width / ciImage.extent.width, size.height / ciImage.extent.height)
            if scale < 1.0 {
                outputImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            }
        }

        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    // MARK: - Filter Implementations

    private func applyExposure(_ image: CIImage, value: Double) -> CIImage {
        // value is in EV (-5 to +5)
        let filter = CIFilter(name: "CIExposureAdjust")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(value, forKey: kCIInputEVKey)
        return filter.outputImage ?? image
    }

    private func applyContrast(_ image: CIImage, value: Double) -> CIImage {
        // value is -100 to +100, map to 0.5 to 1.5
        let contrast = 1.0 + (value / 100.0) * 0.5
        let filter = CIFilter(name: "CIColorControls")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        return filter.outputImage ?? image
    }

    private func applyHighlights(_ image: CIImage, value: Double) -> CIImage {
        // value is -100 to +100
        let filter = CIFilter(name: "CIHighlightShadowAdjust")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.0 - (value / 100.0), forKey: "inputHighlightAmount")
        return filter.outputImage ?? image
    }

    private func applyShadows(_ image: CIImage, value: Double) -> CIImage {
        // value is -100 to +100
        let filter = CIFilter(name: "CIHighlightShadowAdjust")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue((value / 100.0) + 0.5, forKey: "inputShadowAmount")
        return filter.outputImage ?? image
    }

    private func applyWhites(_ image: CIImage, value: Double) -> CIImage {
        // Simulate whites adjustment with tone curve
        // For now, use gamma adjustment on highlights
        let gamma = 1.0 - (value / 200.0)
        let filter = CIFilter(name: "CIGammaAdjust")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(max(0.5, min(1.5, gamma)), forKey: "inputPower")
        return filter.outputImage ?? image
    }

    private func applyBlacks(_ image: CIImage, value: Double) -> CIImage {
        // Adjust black point
        // value is -100 to +100
        let blackPoint = value / 1000.0 // Small adjustment
        let filter = CIFilter(name: "CIColorMatrix")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: blackPoint, y: blackPoint, z: blackPoint, w: 0), forKey: "inputBiasVector")
        return filter.outputImage ?? image
    }

    private func applyTemperature(_ image: CIImage, value: Double) -> CIImage {
        // value is in Kelvin (2000 to 50000, neutral = 6500)
        let filter = CIFilter(name: "CITemperatureAndTint")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: CGFloat(value), y: 0), forKey: "inputNeutral")
        filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputTargetNeutral")
        return filter.outputImage ?? image
    }

    private func applyTint(_ image: CIImage, value: Double) -> CIImage {
        // value is -150 (green) to +150 (magenta)
        let filter = CIFilter(name: "CITemperatureAndTint")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: 6500, y: CGFloat(value)), forKey: "inputNeutral")
        filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputTargetNeutral")
        return filter.outputImage ?? image
    }

    private func applySaturation(_ image: CIImage, value: Double) -> CIImage {
        // value is -100 to +100, map to 0 to 2
        let saturation = 1.0 + (value / 100.0)
        let filter = CIFilter(name: "CIColorControls")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(max(0, saturation), forKey: kCIInputSaturationKey)
        return filter.outputImage ?? image
    }

    private func applyVibrance(_ image: CIImage, value: Double) -> CIImage {
        // value is -100 to +100
        let filter = CIFilter(name: "CIVibrance")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(value / 100.0, forKey: "inputAmount")
        return filter.outputImage ?? image
    }

    private func applySharpening(_ image: CIImage, amount: Double, radius: Double) -> CIImage {
        let filter = CIFilter(name: "CISharpenLuminance")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(amount / 100.0, forKey: kCIInputSharpnessKey)
        return filter.outputImage ?? image
    }

    private func applyNoiseReduction(_ image: CIImage, luminance: Double, color: Double) -> CIImage {
        let filter = CIFilter(name: "CINoiseReduction")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(luminance / 100.0, forKey: "inputNoiseLevel")
        filter.setValue(max(0.02, color / 100.0), forKey: kCIInputSharpnessKey)
        return filter.outputImage ?? image
    }

    private func applyVignette(_ image: CIImage, amount: Double, radius: Double) -> CIImage {
        let filter = CIFilter(name: "CIVignette")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(amount / 100.0 * 2.0, forKey: kCIInputIntensityKey)
        filter.setValue(radius / 100.0 * 2.0, forKey: kCIInputRadiusKey)
        return filter.outputImage ?? image
    }

    private func applyCrop(_ image: CIImage, top: Double, left: Double, bottom: Double, right: Double) -> CIImage {
        let extent = image.extent
        let cropRect = CGRect(
            x: extent.minX + extent.width * left,
            y: extent.minY + extent.height * (1 - bottom),
            width: extent.width * (right - left),
            height: extent.height * (bottom - top)
        )
        return image.cropped(to: cropRect)
    }

    private func applyRotation(_ image: CIImage, angle: Double) -> CIImage {
        // angle is in degrees
        let radians = angle * .pi / 180.0
        let transform = CGAffineTransform(rotationAngle: radians)
        return image.transformed(by: transform)
    }
}

// MARK: - Histogram Generation

extension EditEngine {
    struct Histogram {
        let red: [UInt]
        let green: [UInt]
        let blue: [UInt]
        let luminance: [UInt]
    }

    func generateHistogram(for image: CIImage, bins: Int = 256) -> Histogram {
        // Render small version for histogram
        let scale = 256.0 / max(image.extent.width, image.extent.height)
        let smallImage = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(smallImage, from: smallImage.extent),
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return Histogram(red: [], green: [], blue: [], luminance: [])
        }

        var red = [UInt](repeating: 0, count: bins)
        var green = [UInt](repeating: 0, count: bins)
        var blue = [UInt](repeating: 0, count: bins)
        var luminance = [UInt](repeating: 0, count: bins)

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let pixelCount = cgImage.width * cgImage.height

        for i in 0..<pixelCount {
            let offset = i * bytesPerPixel
            let r = Int(bytes[offset])
            let g = Int(bytes[offset + 1])
            let b = Int(bytes[offset + 2])
            let lum = (r * 299 + g * 587 + b * 114) / 1000

            red[r] += 1
            green[g] += 1
            blue[b] += 1
            luminance[lum] += 1
        }

        return Histogram(red: red, green: green, blue: blue, luminance: luminance)
    }
}
