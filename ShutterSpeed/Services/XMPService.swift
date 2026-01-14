import Foundation

/// Handles XMP sidecar file reading and writing
final class XMPService {
    static let shared = XMPService()

    private init() {}

    // MARK: - Write XMP

    /// Write edit state and metadata to XMP sidecar
    func writeXMP(edits: EditState, metadata: ImageMetadata, to url: URL) throws {
        let xmp = generateXMP(edits: edits, metadata: metadata)
        try xmp.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Generate XMP sidecar for an image
    func generateXMP(for image: PhotoImage, edits: EditState?) -> String {
        generateXMP(edits: edits ?? EditState(imageID: image.id), metadata: image.metadata)
    }

    private func generateXMP(edits: EditState, metadata: ImageMetadata) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about=""
            xmlns:xmp="http://ns.adobe.com/xap/1.0/"
            xmlns:dc="http://purl.org/dc/elements/1.1/"
            xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"
            xmlns:exif="http://ns.adobe.com/exif/1.0/"
            xmlns:tiff="http://ns.adobe.com/tiff/1.0/"
            xmlns:shutterspeed="http://ns.shutterspeed.app/1.0/">

        """

        // XMP metadata
        xml += "    <xmp:CreatorTool>ShutterSpeed 1.0</xmp:CreatorTool>\n"
        xml += "    <xmp:ModifyDate>\(ISO8601DateFormatter().string(from: Date()))</xmp:ModifyDate>\n"

        // Camera Raw settings (compatible with Lightroom/ACR)
        for adjustment in edits.adjustments {
            xml += crsTag(for: adjustment)
        }

        // EXIF data
        if let cameraMake = metadata.cameraMake {
            xml += "    <tiff:Make>\(escapeXML(cameraMake))</tiff:Make>\n"
        }
        if let cameraModel = metadata.cameraModel {
            xml += "    <tiff:Model>\(escapeXML(cameraModel))</tiff:Model>\n"
        }
        if let iso = metadata.iso {
            xml += "    <exif:ISOSpeedRatings><rdf:Seq><rdf:li>\(iso)</rdf:li></rdf:Seq></exif:ISOSpeedRatings>\n"
        }
        if let aperture = metadata.aperture {
            xml += "    <exif:FNumber>\(aperture)</exif:FNumber>\n"
        }
        if let focalLength = metadata.focalLength {
            xml += "    <exif:FocalLength>\(focalLength)</exif:FocalLength>\n"
        }

        // ShutterSpeed-specific data (full edit state as JSON)
        if let jsonData = try? JSONEncoder().encode(edits),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            xml += "    <shutterspeed:EditState>\(escapeXML(jsonString))</shutterspeed:EditState>\n"
        }

        xml += """
        </rdf:Description>
        </rdf:RDF>
        </x:xmpmeta>
        """

        return xml
    }

    private func crsTag(for adjustment: Adjustment) -> String {
        var tags = ""

        switch adjustment.type {
        case .exposure:
            if let value = adjustment.parameters["value"] {
                tags += "    <crs:Exposure2012>\(String(format: "%.2f", value))</crs:Exposure2012>\n"
            }

        case .contrast:
            if let value = adjustment.parameters["value"] {
                tags += "    <crs:Contrast2012>\(Int(value))</crs:Contrast2012>\n"
            }

        case .highlights:
            if let value = adjustment.parameters["value"] {
                tags += "    <crs:Highlights2012>\(Int(value))</crs:Highlights2012>\n"
            }

        case .shadows:
            if let value = adjustment.parameters["value"] {
                tags += "    <crs:Shadows2012>\(Int(value))</crs:Shadows2012>\n"
            }

        case .whites:
            if let value = adjustment.parameters["value"] {
                tags += "    <crs:Whites2012>\(Int(value))</crs:Whites2012>\n"
            }

        case .blacks:
            if let value = adjustment.parameters["value"] {
                tags += "    <crs:Blacks2012>\(Int(value))</crs:Blacks2012>\n"
            }

        case .temperature:
            if let value = adjustment.parameters["value"] {
                tags += "    <crs:Temperature>\(Int(value))</crs:Temperature>\n"
            }

        case .tint:
            if let value = adjustment.parameters["value"] {
                tags += "    <crs:Tint>\(Int(value))</crs:Tint>\n"
            }

        case .saturation:
            if let value = adjustment.parameters["value"] {
                tags += "    <crs:Saturation>\(Int(value))</crs:Saturation>\n"
            }

        case .vibrance:
            if let value = adjustment.parameters["value"] {
                tags += "    <crs:Vibrance>\(Int(value))</crs:Vibrance>\n"
            }

        case .sharpening:
            if let amount = adjustment.parameters["amount"] {
                tags += "    <crs:Sharpness>\(Int(amount))</crs:Sharpness>\n"
            }

        case .noiseReduction:
            if let luminance = adjustment.parameters["luminance"] {
                tags += "    <crs:LuminanceSmoothing>\(Int(luminance))</crs:LuminanceSmoothing>\n"
            }
            if let color = adjustment.parameters["color"] {
                tags += "    <crs:ColorNoiseReduction>\(Int(color))</crs:ColorNoiseReduction>\n"
            }

        case .vignette:
            if let amount = adjustment.parameters["amount"] {
                tags += "    <crs:PostCropVignetteAmount>\(Int(amount))</crs:PostCropVignetteAmount>\n"
            }

        case .crop:
            if let top = adjustment.parameters["top"],
               let left = adjustment.parameters["left"],
               let bottom = adjustment.parameters["bottom"],
               let right = adjustment.parameters["right"] {
                tags += "    <crs:CropTop>\(top)</crs:CropTop>\n"
                tags += "    <crs:CropLeft>\(left)</crs:CropLeft>\n"
                tags += "    <crs:CropBottom>\(bottom)</crs:CropBottom>\n"
                tags += "    <crs:CropRight>\(right)</crs:CropRight>\n"
            }
            if let angle = adjustment.parameters["angle"] {
                tags += "    <crs:CropAngle>\(angle)</crs:CropAngle>\n"
            }

        default:
            break
        }

        return tags
    }

    // MARK: - Read XMP

    /// Read XMP sidecar and extract edit state
    func readXMP(from url: URL) throws -> EditState? {
        let content = try String(contentsOf: url, encoding: .utf8)
        return parseXMP(content)
    }

    /// Find and read XMP sidecar for an image
    func readXMPForImage(at imageURL: URL) throws -> EditState? {
        let xmpURL = imageURL.deletingPathExtension().appendingPathExtension("xmp")

        guard FileManager.default.fileExists(atPath: xmpURL.path) else {
            return nil
        }

        return try readXMP(from: xmpURL)
    }

    private func parseXMP(_ content: String) -> EditState? {
        // Try to extract ShutterSpeed's native JSON first
        if let jsonMatch = content.range(of: "<shutterspeed:EditState>(.+?)</shutterspeed:EditState>",
                                          options: .regularExpression),
           let contentRange = content.range(of: ">(.+?)<", options: .regularExpression, range: jsonMatch) {
            let jsonString = String(content[contentRange]).dropFirst().dropLast()
            let unescaped = unescapeXML(String(jsonString))
            if let data = unescaped.data(using: .utf8),
               let edits = try? JSONDecoder().decode(EditState.self, from: data) {
                return edits
            }
        }

        // Fall back to parsing CRS tags
        return parseCRSTags(content)
    }

    private func parseCRSTags(_ content: String) -> EditState? {
        var adjustments: [Adjustment] = []

        // Extract common CRS values
        let patterns: [(String, AdjustmentType, String)] = [
            ("crs:Exposure2012", .exposure, "value"),
            ("crs:Contrast2012", .contrast, "value"),
            ("crs:Highlights2012", .highlights, "value"),
            ("crs:Shadows2012", .shadows, "value"),
            ("crs:Whites2012", .whites, "value"),
            ("crs:Blacks2012", .blacks, "value"),
            ("crs:Temperature", .temperature, "value"),
            ("crs:Tint", .tint, "value"),
            ("crs:Saturation", .saturation, "value"),
            ("crs:Vibrance", .vibrance, "value"),
            ("crs:Sharpness", .sharpening, "amount"),
        ]

        for (tag, type, param) in patterns {
            if let value = extractValue(for: tag, from: content) {
                var adjustment = Adjustment(type: type)
                adjustment.parameters[param] = value
                adjustments.append(adjustment)
            }
        }

        guard !adjustments.isEmpty else { return nil }

        var editState = EditState(imageID: UUID())
        editState.adjustments = adjustments
        return editState
    }

    private func extractValue(for tag: String, from content: String) -> Double? {
        let pattern = "<\(tag)>([^<]+)</\(tag)>"
        guard let range = content.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        let match = String(content[range])
        let valuePattern = ">([^<]+)<"
        guard let valueRange = match.range(of: valuePattern, options: .regularExpression) else {
            return nil
        }

        let valueString = String(match[valueRange]).dropFirst().dropLast()
        return Double(valueString)
    }

    // MARK: - Helpers

    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func unescapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
    }
}
