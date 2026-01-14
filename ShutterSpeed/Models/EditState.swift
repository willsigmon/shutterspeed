import Foundation

struct EditState: Codable, Identifiable {
    let id: UUID
    let imageID: UUID
    var version: Int
    var adjustments: [Adjustment]
    var createdAt: Date

    init(imageID: UUID, version: Int = 1) {
        self.id = UUID()
        self.imageID = imageID
        self.version = version
        self.adjustments = []
        self.createdAt = Date()
    }
}

struct Adjustment: Codable, Identifiable {
    let id: UUID
    var type: AdjustmentType
    var parameters: [String: Double]
    var enabled: Bool
    var mask: MaskData?

    init(type: AdjustmentType, parameters: [String: Double] = [:]) {
        self.id = UUID()
        self.type = type
        self.parameters = parameters
        self.enabled = true
        self.mask = nil
    }
}

enum AdjustmentType: String, Codable, CaseIterable {
    // Basic
    case exposure
    case contrast
    case highlights
    case shadows
    case whites
    case blacks

    // White Balance
    case temperature
    case tint

    // Tone Curve
    case curves

    // Color
    case saturation
    case vibrance
    case hue

    // Detail
    case sharpening
    case noiseReduction

    // Lens Corrections
    case distortion
    case vignette
    case chromaticAberration

    // Transform
    case crop
    case rotate
    case straighten

    // Local adjustments (Phase 2)
    case brush
    case gradient
    case radial

    var displayName: String {
        switch self {
        case .exposure: return "Exposure"
        case .contrast: return "Contrast"
        case .highlights: return "Highlights"
        case .shadows: return "Shadows"
        case .whites: return "Whites"
        case .blacks: return "Blacks"
        case .temperature: return "Temperature"
        case .tint: return "Tint"
        case .curves: return "Curves"
        case .saturation: return "Saturation"
        case .vibrance: return "Vibrance"
        case .hue: return "Hue"
        case .sharpening: return "Sharpening"
        case .noiseReduction: return "Noise Reduction"
        case .distortion: return "Distortion"
        case .vignette: return "Vignette"
        case .chromaticAberration: return "Chromatic Aberration"
        case .crop: return "Crop"
        case .rotate: return "Rotate"
        case .straighten: return "Straighten"
        case .brush: return "Brush"
        case .gradient: return "Gradient"
        case .radial: return "Radial"
        }
    }

    var defaultParameters: [String: Double] {
        switch self {
        case .exposure: return ["value": 0.0] // -5 to +5 EV
        case .contrast: return ["value": 0.0] // -100 to +100
        case .highlights: return ["value": 0.0]
        case .shadows: return ["value": 0.0]
        case .whites: return ["value": 0.0]
        case .blacks: return ["value": 0.0]
        case .temperature: return ["value": 6500.0] // Kelvin
        case .tint: return ["value": 0.0] // Green to Magenta
        case .saturation: return ["value": 0.0]
        case .vibrance: return ["value": 0.0]
        case .hue: return ["value": 0.0]
        case .sharpening: return ["amount": 0.0, "radius": 1.0, "threshold": 0.0]
        case .noiseReduction: return ["luminance": 0.0, "color": 0.0]
        case .distortion: return ["value": 0.0]
        case .vignette: return ["amount": 0.0, "midpoint": 50.0, "feather": 50.0]
        case .chromaticAberration: return ["red": 0.0, "blue": 0.0]
        case .crop: return ["top": 0.0, "left": 0.0, "bottom": 1.0, "right": 1.0, "angle": 0.0]
        case .rotate: return ["angle": 0.0]
        case .straighten: return ["angle": 0.0]
        case .brush, .gradient, .radial: return [:]
        case .curves: return [:] // Curves use a different data structure
        }
    }
}

struct MaskData: Codable {
    var type: MaskType
    var points: [CGPoint]?
    var gradientStart: CGPoint?
    var gradientEnd: CGPoint?
    var radialCenter: CGPoint?
    var radialSize: CGSize?
    var feather: Double
    var inverted: Bool

    init(type: MaskType, feather: Double = 0.5, inverted: Bool = false) {
        self.type = type
        self.feather = feather
        self.inverted = inverted
    }
}

enum MaskType: String, Codable {
    case brush
    case linearGradient
    case radialGradient
}

// CGPoint Codable conformance
extension CGPoint: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case x, y
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}

extension CGSize: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case width, height
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(width: width, height: height)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}
