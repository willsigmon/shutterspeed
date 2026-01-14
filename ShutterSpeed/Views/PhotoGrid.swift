import SwiftUI

struct PhotoGrid: View {
    let images: [PhotoImage]
    @Binding var selectedIDs: Set<UUID>
    let thumbnailProvider: ThumbnailProvider?
    let gridSize: Double
    var onDoubleClick: ((PhotoImage) -> Void)? = nil

    @State private var hoveredID: UUID?

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: gridSize, maximum: gridSize + 50), spacing: 4)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(images) { image in
                    PhotoThumbnail(
                        image: image,
                        thumbnail: thumbnailProvider?.thumbnails[image.id],
                        isSelected: selectedIDs.contains(image.id),
                        isHovered: hoveredID == image.id,
                        size: gridSize
                    )
                    .onAppear {
                        thumbnailProvider?.loadThumbnail(for: image)
                    }
                    .onDisappear {
                        thumbnailProvider?.cancelLoading(for: image.id)
                    }
                    .onTapGesture(count: 2) {
                        onDoubleClick?(image)
                    }
                    .onTapGesture {
                        handleTap(image: image)
                    }
                    .onHover { hovering in
                        hoveredID = hovering ? image.id : nil
                    }
                    .contextMenu {
                        PhotoContextMenu(image: image)
                    }
                }
            }
            .padding(8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func handleTap(image: PhotoImage) {
        if NSEvent.modifierFlags.contains(.command) {
            // Toggle selection
            if selectedIDs.contains(image.id) {
                selectedIDs.remove(image.id)
            } else {
                selectedIDs.insert(image.id)
            }
        } else if NSEvent.modifierFlags.contains(.shift), let lastSelected = selectedIDs.first {
            // Range selection
            if let startIndex = images.firstIndex(where: { $0.id == lastSelected }),
               let endIndex = images.firstIndex(where: { $0.id == image.id }) {
                let range = min(startIndex, endIndex)...max(startIndex, endIndex)
                for i in range {
                    selectedIDs.insert(images[i].id)
                }
            }
        } else {
            // Single selection
            selectedIDs = [image.id]
        }
    }
}

struct PhotoThumbnail: View {
    let image: PhotoImage
    let thumbnail: NSImage?
    let isSelected: Bool
    let isHovered: Bool
    let size: Double

    var body: some View {
        ZStack {
            // Thumbnail or placeholder
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: size, height: size)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
            }

            // Overlay badges
            VStack {
                HStack {
                    // Flag badge
                    if image.flag != .none {
                        Image(systemName: image.flag.systemImage)
                            .font(.caption)
                            .foregroundStyle(image.flag == .pick ? .green : .red)
                            .padding(4)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Color label
                    if image.colorLabel != .none {
                        Circle()
                            .fill(image.colorLabel.color)
                            .frame(width: 10, height: 10)
                            .padding(4)
                    }
                }

                Spacer()

                HStack {
                    // Rating stars
                    if image.rating > 0 {
                        HStack(spacing: 1) {
                            ForEach(1...image.rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                            }
                        }
                        .foregroundStyle(.yellow)
                        .padding(3)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }

                    Spacer()

                    // RAW badge
                    if isRAWFile {
                        Text("RAW")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.orange)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(4)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
        }
        .shadow(color: isHovered ? .black.opacity(0.2) : .clear, radius: 4)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private var isRAWFile: Bool {
        let ext = image.filePath.pathExtension.lowercased()
        return ["cr2", "cr3", "nef", "arw", "raf", "orf", "dng", "rw2"].contains(ext)
    }
}

struct PhotoContextMenu: View {
    let image: PhotoImage

    var body: some View {
        Group {
            // Rating
            Menu("Rating") {
                ForEach(0...5, id: \.self) { rating in
                    Button {
                        // TODO: Update rating
                    } label: {
                        HStack {
                            if rating == 0 {
                                Text("None")
                            } else {
                                ForEach(1...rating, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                }
                            }
                        }
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(rating)")), modifiers: [])
                }
            }

            // Flags
            Menu("Flag") {
                Button("Pick") {
                    // TODO: Set flag
                }
                .keyboardShortcut("p", modifiers: [])

                Button("Reject") {
                    // TODO: Set flag
                }
                .keyboardShortcut("x", modifiers: [])

                Button("Remove Flag") {
                    // TODO: Remove flag
                }
                .keyboardShortcut("u", modifiers: [])
            }

            // Color labels
            Menu("Color Label") {
                ForEach(ColorLabel.allCases, id: \.self) { label in
                    Button(label.name) {
                        // TODO: Set color label
                    }
                }
            }

            Divider()

            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(image.filePath.path, inFileViewerRootedAtPath: "")
            }

            Button("Get Info") {
                // TODO: Show info panel
            }
            .keyboardShortcut("i", modifiers: .command)

            Divider()

            Button("Delete", role: .destructive) {
                // TODO: Delete image
            }
            .keyboardShortcut(.delete, modifiers: .command)
        }
    }
}

#Preview {
    PhotoGrid(
        images: [],
        selectedIDs: .constant([]),
        thumbnailProvider: nil,
        gridSize: 150
    )
}
