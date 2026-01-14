import SwiftUI

/// RGB histogram visualization
struct HistogramView: View {
    let histogram: Histogram?
    var showChannels: HistogramChannels = .all
    var style: HistogramStyle = .filled

    enum HistogramChannels {
        case luminance
        case rgb
        case all // Luminance + RGB overlaid
    }

    enum HistogramStyle {
        case filled
        case line
        case bars
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.8))

                if let histogram {
                    Canvas { context, size in
                        drawHistogram(context: context, size: size, histogram: histogram)
                    }
                    .padding(4)
                } else {
                    Text("No histogram data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func drawHistogram(context: GraphicsContext, size: CGSize, histogram: Histogram) {
        let binCount = histogram.red.count
        guard binCount > 0 else { return }

        let barWidth = size.width / CGFloat(binCount)

        // Find max value for normalization
        let maxRed = histogram.red.max() ?? 1
        let maxGreen = histogram.green.max() ?? 1
        let maxBlue = histogram.blue.max() ?? 1
        let maxLum = histogram.luminance.max() ?? 1
        let globalMax = max(maxRed, maxGreen, maxBlue, maxLum)

        switch showChannels {
        case .luminance:
            drawChannel(
                context: context,
                size: size,
                data: histogram.luminance,
                color: .white.opacity(0.8),
                maxValue: globalMax,
                barWidth: barWidth
            )

        case .rgb:
            // Draw in order: blue, green, red (so red is on top)
            drawChannel(
                context: context,
                size: size,
                data: histogram.blue,
                color: .blue.opacity(0.5),
                maxValue: globalMax,
                barWidth: barWidth
            )
            drawChannel(
                context: context,
                size: size,
                data: histogram.green,
                color: .green.opacity(0.5),
                maxValue: globalMax,
                barWidth: barWidth
            )
            drawChannel(
                context: context,
                size: size,
                data: histogram.red,
                color: .red.opacity(0.5),
                maxValue: globalMax,
                barWidth: barWidth
            )

        case .all:
            // Draw luminance first, then RGB overlay
            drawChannel(
                context: context,
                size: size,
                data: histogram.luminance,
                color: .gray.opacity(0.3),
                maxValue: globalMax,
                barWidth: barWidth
            )
            drawChannel(
                context: context,
                size: size,
                data: histogram.blue,
                color: .blue.opacity(0.4),
                maxValue: globalMax,
                barWidth: barWidth
            )
            drawChannel(
                context: context,
                size: size,
                data: histogram.green,
                color: .green.opacity(0.4),
                maxValue: globalMax,
                barWidth: barWidth
            )
            drawChannel(
                context: context,
                size: size,
                data: histogram.red,
                color: .red.opacity(0.4),
                maxValue: globalMax,
                barWidth: barWidth
            )
        }
    }

    private func drawChannel(
        context: GraphicsContext,
        size: CGSize,
        data: [Int],
        color: Color,
        maxValue: Int,
        barWidth: CGFloat
    ) {
        switch style {
        case .filled:
            drawFilledHistogram(context: context, size: size, data: data, color: color, maxValue: maxValue, barWidth: barWidth)
        case .line:
            drawLineHistogram(context: context, size: size, data: data, color: color, maxValue: maxValue, barWidth: barWidth)
        case .bars:
            drawBarsHistogram(context: context, size: size, data: data, color: color, maxValue: maxValue, barWidth: barWidth)
        }
    }

    private func drawFilledHistogram(
        context: GraphicsContext,
        size: CGSize,
        data: [Int],
        color: Color,
        maxValue: Int,
        barWidth: CGFloat
    ) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))

        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * barWidth + barWidth / 2
            let normalizedHeight = maxValue > 0 ? CGFloat(value) / CGFloat(maxValue) : 0
            let y = size.height - (normalizedHeight * size.height * 0.95)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()

        context.fill(path, with: .color(color))
    }

    private func drawLineHistogram(
        context: GraphicsContext,
        size: CGSize,
        data: [Int],
        color: Color,
        maxValue: Int,
        barWidth: CGFloat
    ) {
        var path = Path()

        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * barWidth + barWidth / 2
            let normalizedHeight = maxValue > 0 ? CGFloat(value) / CGFloat(maxValue) : 0
            let y = size.height - (normalizedHeight * size.height * 0.95)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(path, with: .color(color), lineWidth: 1)
    }

    private func drawBarsHistogram(
        context: GraphicsContext,
        size: CGSize,
        data: [Int],
        color: Color,
        maxValue: Int,
        barWidth: CGFloat
    ) {
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * barWidth
            let normalizedHeight = maxValue > 0 ? CGFloat(value) / CGFloat(maxValue) : 0
            let barHeight = normalizedHeight * size.height * 0.95

            let rect = CGRect(
                x: x,
                y: size.height - barHeight,
                width: barWidth,
                height: barHeight
            )

            context.fill(Path(rect), with: .color(color))
        }
    }
}

// MARK: - Histogram Data Model

struct Histogram: Equatable {
    let red: [Int]
    let green: [Int]
    let blue: [Int]
    let luminance: [Int]

    static let empty = Histogram(
        red: Array(repeating: 0, count: 256),
        green: Array(repeating: 0, count: 256),
        blue: Array(repeating: 0, count: 256),
        luminance: Array(repeating: 0, count: 256)
    )

    init(red: [Int], green: [Int], blue: [Int], luminance: [Int]) {
        self.red = red
        self.green = green
        self.blue = blue
        self.luminance = luminance
    }

    /// Calculate histogram from CGImage
    static func from(_ image: CGImage) -> Histogram {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return .empty
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var red = [Int](repeating: 0, count: 256)
        var green = [Int](repeating: 0, count: 256)
        var blue = [Int](repeating: 0, count: 256)
        var luminance = [Int](repeating: 0, count: 256)

        // Sample every Nth pixel for performance on large images
        let sampleRate = max(1, (width * height) / 500000)

        for y in stride(from: 0, to: height, by: sampleRate) {
            for x in stride(from: 0, to: width, by: sampleRate) {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = Int(pixelData[offset])
                let g = Int(pixelData[offset + 1])
                let b = Int(pixelData[offset + 2])

                red[r] += 1
                green[g] += 1
                blue[b] += 1

                // Calculate luminance: Y = 0.299R + 0.587G + 0.114B
                let lum = Int(Double(r) * 0.299 + Double(g) * 0.587 + Double(b) * 0.114)
                luminance[min(255, lum)] += 1
            }
        }

        return Histogram(red: red, green: green, blue: blue, luminance: luminance)
    }

    /// Calculate histogram from NSImage
    static func from(_ image: NSImage) -> Histogram {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .empty
        }
        return from(cgImage)
    }
}

// MARK: - Compact Histogram (for toolbar/inspector)

struct CompactHistogramView: View {
    let histogram: Histogram?

    var body: some View {
        HistogramView(
            histogram: histogram,
            showChannels: .all,
            style: .filled
        )
        .frame(height: 50)
    }
}

// MARK: - Expanded Histogram (for overlay/modal)

struct ExpandedHistogramView: View {
    let histogram: Histogram?
    @State private var selectedChannel: HistogramView.HistogramChannels = .all

    var body: some View {
        VStack(spacing: 8) {
            // Channel picker
            Picker("Channel", selection: $selectedChannel) {
                Text("All").tag(HistogramView.HistogramChannels.all)
                Text("RGB").tag(HistogramView.HistogramChannels.rgb)
                Text("Luma").tag(HistogramView.HistogramChannels.luminance)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Histogram
            HistogramView(
                histogram: histogram,
                showChannels: selectedChannel,
                style: .filled
            )

            // Stats
            if let histogram {
                HStack(spacing: 16) {
                    StatView(label: "Shadows", value: calculateShadows(histogram))
                    StatView(label: "Midtones", value: calculateMidtones(histogram))
                    StatView(label: "Highlights", value: calculateHighlights(histogram))
                }
                .font(.caption)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func calculateShadows(_ histogram: Histogram) -> String {
        let shadowRange = 0..<85
        let total = histogram.luminance.reduce(0, +)
        let shadows = histogram.luminance[shadowRange].reduce(0, +)
        let percentage = total > 0 ? (Double(shadows) / Double(total)) * 100 : 0
        return String(format: "%.0f%%", percentage)
    }

    private func calculateMidtones(_ histogram: Histogram) -> String {
        let midRange = 85..<170
        let total = histogram.luminance.reduce(0, +)
        let mids = histogram.luminance[midRange].reduce(0, +)
        let percentage = total > 0 ? (Double(mids) / Double(total)) * 100 : 0
        return String(format: "%.0f%%", percentage)
    }

    private func calculateHighlights(_ histogram: Histogram) -> String {
        let highlightRange = 170..<256
        let total = histogram.luminance.reduce(0, +)
        let highlights = histogram.luminance[highlightRange].reduce(0, +)
        let percentage = total > 0 ? (Double(highlights) / Double(total)) * 100 : 0
        return String(format: "%.0f%%", percentage)
    }
}

private struct StatView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CompactHistogramView(histogram: .empty)
            .frame(width: 200)

        ExpandedHistogramView(histogram: .empty)
            .frame(width: 300, height: 200)
    }
    .padding()
}
