import SwiftUI

/// Interactive crop tool overlay
struct CropToolView: View {
    let imageSize: CGSize
    @Binding var cropRect: CGRect
    @Binding var rotation: Double
    @Binding var aspectRatio: AspectRatio

    @State private var dragHandle: CropHandle?
    @State private var dragStart: CGPoint = .zero
    @State private var originalRect: CGRect = .zero

    enum AspectRatio: String, CaseIterable, Identifiable {
        case freeform = "Freeform"
        case original = "Original"
        case square = "1:1"
        case ratio4x3 = "4:3"
        case ratio3x2 = "3:2"
        case ratio16x9 = "16:9"
        case ratio5x4 = "5:4"
        case ratio7x5 = "7:5"

        var id: String { rawValue }

        var ratio: CGFloat? {
            switch self {
            case .freeform: return nil
            case .original: return nil  // Calculated from image
            case .square: return 1.0
            case .ratio4x3: return 4.0 / 3.0
            case .ratio3x2: return 3.0 / 2.0
            case .ratio16x9: return 16.0 / 9.0
            case .ratio5x4: return 5.0 / 4.0
            case .ratio7x5: return 7.0 / 5.0
            }
        }
    }

    enum CropHandle {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
        case center
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Darkened overlay outside crop area
                darkenedOverlay(in: geometry.size)

                // Crop rectangle
                cropRectangle(in: geometry.size)

                // Grid overlay
                gridOverlay(in: geometry.size)

                // Corner and edge handles
                handles(in: geometry.size)
            }
            .gesture(dragGesture(in: geometry.size))
        }
    }

    // MARK: - Darkened Overlay

    private func darkenedOverlay(in size: CGSize) -> some View {
        let scaledRect = scaledCropRect(for: size)

        return Path { path in
            // Full frame
            path.addRect(CGRect(origin: .zero, size: size))
            // Subtract crop area
            path.addRect(scaledRect)
        }
        .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
    }

    // MARK: - Crop Rectangle

    private func cropRectangle(in size: CGSize) -> some View {
        let scaledRect = scaledCropRect(for: size)

        return Rectangle()
            .stroke(.white, lineWidth: 1)
            .frame(width: scaledRect.width, height: scaledRect.height)
            .position(x: scaledRect.midX, y: scaledRect.midY)
    }

    // MARK: - Grid Overlay (Rule of Thirds)

    private func gridOverlay(in size: CGSize) -> some View {
        let scaledRect = scaledCropRect(for: size)

        return ZStack {
            // Vertical lines
            ForEach(1..<3, id: \.self) { i in
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 1, height: scaledRect.height)
                    .position(
                        x: scaledRect.minX + (scaledRect.width / 3 * CGFloat(i)),
                        y: scaledRect.midY
                    )
            }

            // Horizontal lines
            ForEach(1..<3, id: \.self) { i in
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: scaledRect.width, height: 1)
                    .position(
                        x: scaledRect.midX,
                        y: scaledRect.minY + (scaledRect.height / 3 * CGFloat(i))
                    )
            }
        }
    }

    // MARK: - Handles

    private func handles(in size: CGSize) -> some View {
        let scaledRect = scaledCropRect(for: size)
        let handleSize: CGFloat = 20

        return ZStack {
            // Corners
            handleView(at: CGPoint(x: scaledRect.minX, y: scaledRect.minY), size: handleSize)
            handleView(at: CGPoint(x: scaledRect.maxX, y: scaledRect.minY), size: handleSize)
            handleView(at: CGPoint(x: scaledRect.minX, y: scaledRect.maxY), size: handleSize)
            handleView(at: CGPoint(x: scaledRect.maxX, y: scaledRect.maxY), size: handleSize)

            // Edge midpoints
            handleView(at: CGPoint(x: scaledRect.midX, y: scaledRect.minY), size: handleSize, isEdge: true)
            handleView(at: CGPoint(x: scaledRect.midX, y: scaledRect.maxY), size: handleSize, isEdge: true)
            handleView(at: CGPoint(x: scaledRect.minX, y: scaledRect.midY), size: handleSize, isEdge: true)
            handleView(at: CGPoint(x: scaledRect.maxX, y: scaledRect.midY), size: handleSize, isEdge: true)
        }
    }

    private func handleView(at point: CGPoint, size: CGFloat, isEdge: Bool = false) -> some View {
        Group {
            if isEdge {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white)
                    .frame(width: size / 2, height: size / 2)
            } else {
                // Corner handle - L-shaped
                ZStack {
                    Rectangle()
                        .fill(.white)
                        .frame(width: size, height: 3)
                    Rectangle()
                        .fill(.white)
                        .frame(width: 3, height: size)
                }
            }
        }
        .position(point)
    }

    // MARK: - Gesture

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragHandle == nil {
                    // Determine which handle was grabbed
                    let scaledRect = scaledCropRect(for: size)
                    dragHandle = hitTestHandle(at: value.startLocation, in: scaledRect)
                    dragStart = value.startLocation
                    originalRect = cropRect
                }

                handleDrag(value: value, viewSize: size)
            }
            .onEnded { _ in
                dragHandle = nil
            }
    }

    private func hitTestHandle(at point: CGPoint, in rect: CGRect) -> CropHandle? {
        let threshold: CGFloat = 20

        // Check corners first
        if distance(from: point, to: CGPoint(x: rect.minX, y: rect.minY)) < threshold {
            return .topLeft
        }
        if distance(from: point, to: CGPoint(x: rect.maxX, y: rect.minY)) < threshold {
            return .topRight
        }
        if distance(from: point, to: CGPoint(x: rect.minX, y: rect.maxY)) < threshold {
            return .bottomLeft
        }
        if distance(from: point, to: CGPoint(x: rect.maxX, y: rect.maxY)) < threshold {
            return .bottomRight
        }

        // Check edges
        if abs(point.y - rect.minY) < threshold && point.x > rect.minX && point.x < rect.maxX {
            return .top
        }
        if abs(point.y - rect.maxY) < threshold && point.x > rect.minX && point.x < rect.maxX {
            return .bottom
        }
        if abs(point.x - rect.minX) < threshold && point.y > rect.minY && point.y < rect.maxY {
            return .left
        }
        if abs(point.x - rect.maxX) < threshold && point.y > rect.minY && point.y < rect.maxY {
            return .right
        }

        // Check center
        if rect.contains(point) {
            return .center
        }

        return nil
    }

    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
    }

    private func handleDrag(value: DragGesture.Value, viewSize: CGSize) {
        guard let handle = dragHandle else { return }

        let scale = viewSize.width / imageSize.width
        let deltaX = (value.translation.width) / scale
        let deltaY = (value.translation.height) / scale

        var newRect = originalRect

        switch handle {
        case .topLeft:
            newRect.origin.x += deltaX
            newRect.origin.y += deltaY
            newRect.size.width -= deltaX
            newRect.size.height -= deltaY

        case .topRight:
            newRect.origin.y += deltaY
            newRect.size.width += deltaX
            newRect.size.height -= deltaY

        case .bottomLeft:
            newRect.origin.x += deltaX
            newRect.size.width -= deltaX
            newRect.size.height += deltaY

        case .bottomRight:
            newRect.size.width += deltaX
            newRect.size.height += deltaY

        case .top:
            newRect.origin.y += deltaY
            newRect.size.height -= deltaY

        case .bottom:
            newRect.size.height += deltaY

        case .left:
            newRect.origin.x += deltaX
            newRect.size.width -= deltaX

        case .right:
            newRect.size.width += deltaX

        case .center:
            newRect.origin.x += deltaX
            newRect.origin.y += deltaY
        }

        // Constrain to image bounds
        newRect = constrainRect(newRect, to: CGRect(origin: .zero, size: imageSize))

        // Apply aspect ratio if needed
        if let ratio = aspectRatio.ratio {
            newRect = applyAspectRatio(to: newRect, ratio: ratio, anchor: handle)
        }

        // Minimum size
        if newRect.width >= 50 && newRect.height >= 50 {
            cropRect = newRect
        }
    }

    private func constrainRect(_ rect: CGRect, to bounds: CGRect) -> CGRect {
        var result = rect

        // Keep within bounds
        result.origin.x = max(bounds.minX, min(result.origin.x, bounds.maxX - result.width))
        result.origin.y = max(bounds.minY, min(result.origin.y, bounds.maxY - result.height))
        result.size.width = min(result.width, bounds.maxX - result.origin.x)
        result.size.height = min(result.height, bounds.maxY - result.origin.y)

        return result
    }

    private func applyAspectRatio(to rect: CGRect, ratio: CGFloat, anchor: CropHandle) -> CGRect {
        var result = rect

        switch anchor {
        case .topLeft, .bottomLeft, .left:
            result.size.height = result.width / ratio

        case .topRight, .bottomRight, .right, .top, .bottom:
            result.size.width = result.height * ratio

        case .center:
            // Keep current size when moving
            break
        }

        return result
    }

    // MARK: - Helpers

    private func scaledCropRect(for viewSize: CGSize) -> CGRect {
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        let scale = min(scaleX, scaleY)

        let offsetX = (viewSize.width - imageSize.width * scale) / 2
        let offsetY = (viewSize.height - imageSize.height * scale) / 2

        return CGRect(
            x: cropRect.origin.x * scale + offsetX,
            y: cropRect.origin.y * scale + offsetY,
            width: cropRect.width * scale,
            height: cropRect.height * scale
        )
    }
}

// MARK: - Crop Tool Controls

struct CropToolControls: View {
    @Binding var aspectRatio: CropToolView.AspectRatio
    @Binding var rotation: Double
    let onReset: () -> Void
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Aspect ratio picker
            Menu {
                ForEach(CropToolView.AspectRatio.allCases) { ratio in
                    Button {
                        aspectRatio = ratio
                    } label: {
                        HStack {
                            Text(ratio.rawValue)
                            if aspectRatio == ratio {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "aspectratio")
                    Text(aspectRatio.rawValue)
                }
            }
            .menuStyle(.borderlessButton)

            Divider()
                .frame(height: 20)

            // Rotation controls
            HStack(spacing: 8) {
                Button {
                    rotation -= 90
                } label: {
                    Image(systemName: "rotate.left")
                }

                Button {
                    rotation += 90
                } label: {
                    Image(systemName: "rotate.right")
                }

                Slider(value: $rotation, in: -45...45)
                    .frame(width: 100)

                Text("\(String(format: "%.1f", rotation))°")
                    .monospacedDigit()
                    .frame(width: 50)
            }
            .buttonStyle(.borderless)

            Spacer()

            // Action buttons
            Button("Reset", action: onReset)
                .buttonStyle(.borderless)

            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)

            Button("Done", action: onDone)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

// MARK: - Straighten Tool

struct StraightenToolView: View {
    @Binding var angle: Double
    let onAutoStraighten: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text("Straighten")
                .foregroundStyle(.secondary)

            Slider(value: $angle, in: -10...10, step: 0.1)
                .frame(width: 200)

            Text("\(String(format: "%.1f", angle))°")
                .monospacedDigit()
                .frame(width: 50)

            Button("Auto") {
                onAutoStraighten()
            }
            .buttonStyle(.borderless)

            Button("Reset") {
                angle = 0
            }
            .buttonStyle(.borderless)
        }
        .padding()
    }
}

#Preview {
    ZStack {
        Color.gray

        CropToolView(
            imageSize: CGSize(width: 4000, height: 3000),
            cropRect: .constant(CGRect(x: 500, y: 375, width: 3000, height: 2250)),
            rotation: .constant(0),
            aspectRatio: .constant(.freeform)
        )
    }
    .frame(width: 800, height: 600)
}
