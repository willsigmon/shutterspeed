import SwiftUI
import AppKit

/// Full-screen detail view for single image editing
struct DetailViewer: View {
    let image: PhotoImage
    let library: PhotoLibrary
    @Binding var editState: EditState?
    @Environment(\.dismiss) private var dismiss

    @State private var displayImage: NSImage?
    @State private var isLoading = true
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var showBefore = false
    @State private var showHistogram = false
    @State private var showLoupe = false
    @State private var loupePosition: CGPoint = .zero

    private let editEngine = EditEngine.shared
    private let rawProcessor = RAWProcessor.shared

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Main image
            GeometryReader { geometry in
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let displayImage {
                    ZStack {
                        // Image with zoom/pan
                        Image(nsImage: displayImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(zoomScale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        zoomScale = max(1.0, min(10.0, value))
                                    }
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if zoomScale > 1.0 {
                                            offset = value.translation
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    if zoomScale > 1.0 {
                                        zoomScale = 1.0
                                        offset = .zero
                                    } else {
                                        zoomScale = 2.0
                                    }
                                }
                            }

                        // Loupe overlay
                        if showLoupe {
                            LoupeView(
                                image: displayImage,
                                position: loupePosition,
                                zoomLevel: 4.0
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            loupePosition = location
                        case .ended:
                            break
                        }
                    }
                }
            }

            // Toolbar overlay
            VStack {
                DetailToolbar(
                    showBefore: $showBefore,
                    showHistogram: $showHistogram,
                    showLoupe: $showLoupe,
                    zoomScale: $zoomScale,
                    onClose: { dismiss() }
                )

                Spacer()

                // Bottom info bar
                DetailInfoBar(image: image)
            }

            // Histogram overlay
            if showHistogram, let displayImage {
                VStack {
                    HStack {
                        Spacer()
                        HistogramView(image: displayImage)
                            .frame(width: 200, height: 120)
                            .padding()
                    }
                    Spacer()
                }
            }
        }
        .task {
            await loadImage()
        }
        .onChange(of: editState) { _, _ in
            Task {
                await loadImage()
            }
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            // TODO: Previous image
            return .handled
        }
        .onKeyPress(.rightArrow) {
            // TODO: Next image
            return .handled
        }
    }

    private func loadImage() async {
        await MainActor.run { isLoading = true }

        let ciImage: CIImage
        do {
            if showBefore || editState == nil || editState!.adjustments.isEmpty {
                ciImage = try rawProcessor.loadImage(from: image.filePath)
            } else {
                ciImage = try editEngine.apply(edits: editState!, to: image.filePath)
            }

            let nsImage = editEngine.render(ciImage)
            await MainActor.run {
                displayImage = nsImage
                isLoading = false
            }
        } catch {
            print("Failed to load image: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Detail Toolbar

struct DetailToolbar: View {
    @Binding var showBefore: Bool
    @Binding var showHistogram: Bool
    @Binding var showLoupe: Bool
    @Binding var zoomScale: CGFloat

    let onClose: () -> Void

    var body: some View {
        HStack {
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)

            Spacer()

            // View controls
            HStack(spacing: 16) {
                // Before/After toggle
                Toggle(isOn: $showBefore) {
                    Image(systemName: "rectangle.lefthalf.inset.filled.arrow.left")
                }
                .toggleStyle(.button)
                .help("Show original (\\)")

                // Histogram toggle
                Toggle(isOn: $showHistogram) {
                    Image(systemName: "waveform")
                }
                .toggleStyle(.button)
                .help("Show histogram")

                // Loupe toggle
                Toggle(isOn: $showLoupe) {
                    Image(systemName: "magnifyingglass")
                }
                .toggleStyle(.button)
                .help("Show loupe (L)")

                Divider()
                    .frame(height: 20)

                // Zoom controls
                Button(action: { zoomScale = max(1.0, zoomScale - 0.5) }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.plain)
                .disabled(zoomScale <= 1.0)

                Text("\(Int(zoomScale * 100))%")
                    .monospacedDigit()
                    .frame(width: 50)

                Button(action: { zoomScale = min(10.0, zoomScale + 0.5) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.plain)
                .disabled(zoomScale >= 10.0)

                Button(action: {
                    zoomScale = 1.0
                    // offset = .zero
                }) {
                    Text("Fit")
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Placeholder for symmetry
            Color.clear
                .frame(width: 44)
        }
        .padding()
        .background(.ultraThinMaterial)
        .foregroundStyle(.white)
    }
}

// MARK: - Detail Info Bar

struct DetailInfoBar: View {
    let image: PhotoImage

    var body: some View {
        HStack {
            // File info
            Text(image.fileName)
                .fontWeight(.medium)

            Spacer()

            // Exposure info
            HStack(spacing: 12) {
                if let iso = image.metadata.iso {
                    Text("ISO \(iso)")
                }
                if let aperture = image.metadata.aperture {
                    Text("f/\(String(format: "%.1f", aperture))")
                }
                if let shutter = image.metadata.shutterSpeed {
                    Text(shutter)
                }
                if let focal = image.metadata.focalLength {
                    Text("\(Int(focal))mm")
                }
            }
            .font(.callout.monospacedDigit())

            Spacer()

            // Rating
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= image.rating ? "star.fill" : "star")
                        .foregroundStyle(star <= image.rating ? .yellow : .gray)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .foregroundStyle(.white)
    }
}

// MARK: - Loupe View

struct LoupeView: View {
    let image: NSImage
    let position: CGPoint
    let zoomLevel: CGFloat

    private let loupeSize: CGFloat = 150

    var body: some View {
        Circle()
            .fill(.clear)
            .frame(width: loupeSize, height: loupeSize)
            .overlay {
                // Zoomed portion of image
                GeometryReader { geometry in
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(zoomLevel)
                        .offset(
                            x: -position.x * zoomLevel + loupeSize / 2,
                            y: -position.y * zoomLevel + loupeSize / 2
                        )
                }
                .clipShape(Circle())
            }
            .overlay {
                Circle()
                    .stroke(.white, lineWidth: 2)
            }
            .shadow(radius: 10)
            .position(x: position.x + 80, y: position.y - 80)
    }
}

// MARK: - Histogram View

struct HistogramView: View {
    let image: NSImage

    @State private var histogram: EditEngine.Histogram?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.7))

            if let histogram {
                Canvas { context, size in
                    drawHistogram(context: context, size: size, data: histogram.luminance, color: .white)
                    drawHistogram(context: context, size: size, data: histogram.red, color: .red.opacity(0.5))
                    drawHistogram(context: context, size: size, data: histogram.green, color: .green.opacity(0.5))
                    drawHistogram(context: context, size: size, data: histogram.blue, color: .blue.opacity(0.5))
                }
            } else {
                ProgressView()
            }
        }
        .task {
            await generateHistogram()
        }
    }

    private func generateHistogram() async {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let ciImage = CIImage(cgImage: cgImage)
        let hist = EditEngine.shared.generateHistogram(for: ciImage)
        await MainActor.run {
            histogram = hist
        }
    }

    private func drawHistogram(context: GraphicsContext, size: CGSize, data: [UInt], color: Color) {
        guard !data.isEmpty else { return }

        let maxValue = data.max() ?? 1
        let barWidth = size.width / CGFloat(data.count)

        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))

        for (index, value) in data.enumerated() {
            let height = CGFloat(value) / CGFloat(maxValue) * size.height
            let x = CGFloat(index) * barWidth
            path.addLine(to: CGPoint(x: x, y: size.height - height))
        }

        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()

        context.fill(path, with: .color(color))
    }
}

#Preview {
    DetailViewer(
        image: PhotoImage(
            id: UUID(),
            filePath: URL(fileURLWithPath: "/tmp/test.jpg"),
            fileName: "test.jpg"
        ),
        library: PhotoLibrary.preview,
        editState: .constant(nil)
    )
}
