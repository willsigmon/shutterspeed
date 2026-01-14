import SwiftUI

/// Side-by-side comparison view for before/after or multiple images
struct CompareView: View {
    let images: [PhotoImage]
    let edits: [UUID: EditState]
    @Binding var mode: CompareMode

    @State private var splitPosition: CGFloat = 0.5
    @State private var isLoadingLeft = true
    @State private var isLoadingRight = true
    @State private var leftImage: NSImage?
    @State private var rightImage: NSImage?

    private let editEngine = EditEngine.shared
    private let rawProcessor = RAWProcessor.shared

    enum CompareMode: String, CaseIterable {
        case split = "Split"
        case sideBySide = "Side by Side"
        case beforeAfter = "Before/After"
    }

    var body: some View {
        GeometryReader { geometry in
            switch mode {
            case .split:
                splitView(in: geometry)
            case .sideBySide:
                sideBySideView(in: geometry)
            case .beforeAfter:
                beforeAfterView(in: geometry)
            }
        }
        .background(Color.black)
        .task {
            await loadImages()
        }
    }

    // MARK: - Split View (Slider Reveal)

    private func splitView(in geometry: GeometryProxy) -> some View {
        ZStack {
            // After (edited) - full width, underneath
            if let rightImage {
                Image(nsImage: rightImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }

            // Before (original) - clipped to left portion
            if let leftImage {
                Image(nsImage: leftImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .mask(
                        Rectangle()
                            .frame(width: geometry.size.width * splitPosition)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )
            }

            // Divider line
            Rectangle()
                .fill(.white)
                .frame(width: 2)
                .position(x: geometry.size.width * splitPosition, y: geometry.size.height / 2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            splitPosition = max(0.1, min(0.9, value.location.x / geometry.size.width))
                        }
                )

            // Handle
            Circle()
                .fill(.white)
                .frame(width: 24, height: 24)
                .overlay {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption2)
                    .foregroundStyle(.black)
                }
                .position(x: geometry.size.width * splitPosition, y: geometry.size.height / 2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            splitPosition = max(0.1, min(0.9, value.location.x / geometry.size.width))
                        }
                )

            // Labels
            VStack {
                HStack {
                    Text("BEFORE")
                        .font(.caption.bold())
                        .padding(6)
                        .background(.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Spacer()

                    Text("AFTER")
                        .font(.caption.bold())
                        .padding(6)
                        .background(.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding()
                .foregroundStyle(.white)

                Spacer()
            }
        }
    }

    // MARK: - Side by Side View

    private func sideBySideView(in geometry: GeometryProxy) -> some View {
        HStack(spacing: 2) {
            // Left image
            VStack {
                if isLoadingLeft {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let leftImage {
                    Image(nsImage: leftImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }

                Text(images.first?.fileName ?? "Original")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(4)
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(.gray)
                .frame(width: 2)

            // Right image
            VStack {
                if isLoadingRight {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let rightImage {
                    Image(nsImage: rightImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }

                Text(images.count > 1 ? (images[1].fileName) : "Edited")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(4)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Before/After Toggle View

    private func beforeAfterView(in geometry: GeometryProxy) -> some View {
        ZStack {
            if let leftImage {
                Image(nsImage: leftImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }

            // Overlay hint
            VStack {
                Spacer()
                Text("Hold \\ to see original")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(8)
                    .background(.black.opacity(0.5))
                    .clipShape(Capsule())
                    .padding()
            }
        }
    }

    // MARK: - Loading

    private func loadImages() async {
        guard let firstImage = images.first else { return }

        // Load before (original)
        Task {
            do {
                let ciImage = try rawProcessor.loadImage(from: firstImage.filePath)
                let nsImage = editEngine.render(ciImage)
                await MainActor.run {
                    leftImage = nsImage
                    isLoadingLeft = false
                }
            } catch {
                await MainActor.run { isLoadingLeft = false }
            }
        }

        // Load after (edited) or second image
        Task {
            do {
                let ciImage: CIImage

                if images.count > 1 {
                    // Compare two different images
                    ciImage = try rawProcessor.loadImage(from: images[1].filePath)
                } else if let edit = edits[firstImage.id], !edit.adjustments.isEmpty {
                    // Compare original vs edited
                    ciImage = try editEngine.apply(edits: edit, to: firstImage.filePath)
                } else {
                    // No edits, show same as left
                    ciImage = try rawProcessor.loadImage(from: firstImage.filePath)
                }

                let nsImage = editEngine.render(ciImage)
                await MainActor.run {
                    rightImage = nsImage
                    isLoadingRight = false
                }
            } catch {
                await MainActor.run { isLoadingRight = false }
            }
        }
    }
}

// MARK: - Compare Mode Picker

struct CompareModePicker: View {
    @Binding var mode: CompareView.CompareMode

    var body: some View {
        Picker("Compare Mode", selection: $mode) {
            ForEach(CompareView.CompareMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
}

#Preview {
    CompareView(
        images: [],
        edits: [:],
        mode: .constant(.split)
    )
}
