import SwiftUI

// MARK: - Photo Context Menu

/// Context menu for individual photos in grid or detail view
struct PhotoContextMenu: View {
    @Bindable var image: PhotoImage
    let onOpenInDetail: () -> Void
    let onCompareWith: () -> Void
    let onShowInFinder: () -> Void
    let onExport: () -> Void
    let onCopyAdjustments: () -> Void
    let onPasteAdjustments: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
            // Primary actions
            Button {
                onOpenInDetail()
            } label: {
                Label("Edit in Detail View", systemImage: "slider.horizontal.3")
            }

            Button {
                onCompareWith()
            } label: {
                Label("Compare With...", systemImage: "rectangle.on.rectangle")
            }

            Divider()

            // Rating submenu
            ratingMenu

            // Flag submenu
            flagMenu

            // Color label submenu
            colorLabelMenu

            Divider()

            // Rotation actions
            HStack {
                Button {
                    image.editState.rotation -= 90
                } label: {
                    Label("Rotate Left", systemImage: "rotate.left")
                }

                Button {
                    image.editState.rotation += 90
                } label: {
                    Label("Rotate Right", systemImage: "rotate.right")
                }
            }

            Divider()

            // Adjustments
            Button {
                onCopyAdjustments()
            } label: {
                Label("Copy Adjustments", systemImage: "doc.on.doc")
            }

            Button {
                onPasteAdjustments()
            } label: {
                Label("Paste Adjustments", systemImage: "doc.on.clipboard")
            }

            Button {
                image.editState = EditState()
            } label: {
                Label("Reset Adjustments", systemImage: "arrow.uturn.backward")
            }

            Divider()

            // File operations
            Button {
                onShowInFinder()
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }

            Button {
                onExport()
            } label: {
                Label("Export...", systemImage: "square.and.arrow.up")
            }

            Divider()

            // Destructive actions
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }

    private var ratingMenu: some View {
        Menu {
            ForEach(0...5, id: \.self) { rating in
                Button {
                    image.rating = rating
                } label: {
                    HStack {
                        Text(rating == 0 ? "No Rating" : String(repeating: "\u{2605}", count: rating))
                        if image.rating == rating {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label {
                Text("Set Rating")
            } icon: {
                Image(systemName: "star")
            }
        }
    }

    private var flagMenu: some View {
        Menu {
            Button {
                image.flag = .pick
            } label: {
                HStack {
                    Label("Pick", systemImage: "flag.fill")
                        .foregroundStyle(.white)
                    if image.flag == .pick {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Button {
                image.flag = .reject
            } label: {
                HStack {
                    Label("Reject", systemImage: "xmark")
                        .foregroundStyle(.red)
                    if image.flag == .reject {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Button {
                image.flag = .unflagged
            } label: {
                HStack {
                    Label("Unflagged", systemImage: "flag")
                    if image.flag == .unflagged {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Label("Set Flag", systemImage: "flag")
        }
    }

    private var colorLabelMenu: some View {
        Menu {
            ForEach(ColorLabel.allCases, id: \.self) { label in
                Button {
                    image.colorLabel = label
                } label: {
                    HStack {
                        if label != .none {
                            Circle()
                                .fill(label.color)
                                .frame(width: 10, height: 10)
                        }
                        Text(label.rawValue.capitalized)
                        if image.colorLabel == label {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Set Color Label", systemImage: "circle.fill")
        }
    }
}

// MARK: - Multi-Selection Context Menu

/// Context menu for multiple selected photos
struct MultiPhotoContextMenu: View {
    let images: [PhotoImage]
    let onExport: () -> Void
    let onCopyAdjustments: () -> Void
    let onPasteAdjustments: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
            Text("\(images.count) Photos Selected")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Batch rating
            Menu {
                ForEach(0...5, id: \.self) { rating in
                    Button(rating == 0 ? "No Rating" : String(repeating: "\u{2605}", count: rating)) {
                        for image in images {
                            image.rating = rating
                        }
                    }
                }
            } label: {
                Label("Set Rating", systemImage: "star")
            }

            // Batch flag
            Menu {
                Button("Pick") {
                    for image in images {
                        image.flag = .pick
                    }
                }
                Button("Reject") {
                    for image in images {
                        image.flag = .reject
                    }
                }
                Button("Unflagged") {
                    for image in images {
                        image.flag = .unflagged
                    }
                }
            } label: {
                Label("Set Flag", systemImage: "flag")
            }

            // Batch color label
            Menu {
                ForEach(ColorLabel.allCases, id: \.self) { label in
                    Button {
                        for image in images {
                            image.colorLabel = label
                        }
                    } label: {
                        HStack {
                            if label != .none {
                                Circle()
                                    .fill(label.color)
                                    .frame(width: 10, height: 10)
                            }
                            Text(label.rawValue.capitalized)
                        }
                    }
                }
            } label: {
                Label("Set Color Label", systemImage: "circle.fill")
            }

            Divider()

            // Batch adjustments
            Button {
                onPasteAdjustments()
            } label: {
                Label("Paste Adjustments to All", systemImage: "doc.on.clipboard")
            }

            Button {
                for image in images {
                    image.editState = EditState()
                }
            } label: {
                Label("Reset All Adjustments", systemImage: "arrow.uturn.backward")
            }

            Divider()

            Button {
                onExport()
            } label: {
                Label("Export \(images.count) Photos...", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Move \(images.count) Photos to Trash", systemImage: "trash")
            }
        }
    }
}

// MARK: - Album Context Menu

/// Context menu for albums in sidebar
struct AlbumContextMenu: View {
    let album: Album
    let onRename: () -> Void
    let onDelete: () -> Void
    let onExportAll: () -> Void

    var body: some View {
        Group {
            Button {
                onRename()
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button {
                onExportAll()
            } label: {
                Label("Export All Photos...", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Album", systemImage: "trash")
            }

            Text("Album will be deleted. Photos will remain in library.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Folder Context Menu

/// Context menu for folders in sidebar
struct FolderContextMenu: View {
    let folder: Folder
    let onRename: () -> Void
    let onCreateSubfolder: () -> Void
    let onCreateAlbum: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
            Button {
                onRename()
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button {
                onCreateSubfolder()
            } label: {
                Label("New Subfolder", systemImage: "folder.badge.plus")
            }

            Button {
                onCreateAlbum()
            } label: {
                Label("New Album", systemImage: "rectangle.stack.badge.plus")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Folder", systemImage: "trash")
            }
        }
    }
}

// MARK: - Smart Album Context Menu

/// Context menu for smart albums (Album with isSmart = true)
struct SmartAlbumContextMenu: View {
    let album: Album
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
            Button {
                onEdit()
            } label: {
                Label("Edit Smart Album...", systemImage: "slider.horizontal.3")
            }

            Button {
                onDuplicate()
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Smart Album", systemImage: "trash")
            }
        }
    }
}

// MARK: - Grid Background Context Menu

/// Context menu when right-clicking empty space in grid
struct GridBackgroundContextMenu: View {
    let onImport: () -> Void
    let onSelectAll: () -> Void
    let onPaste: () -> Void
    @Binding var sortOrder: SortOrder
    @Binding var gridSize: Double

    var body: some View {
        Group {
            Button {
                onImport()
            } label: {
                Label("Import Photos...", systemImage: "square.and.arrow.down")
            }

            Divider()

            Button {
                onSelectAll()
            } label: {
                Label("Select All", systemImage: "checkmark.circle")
            }

            Button {
                onPaste()
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
            }

            Divider()

            // Sort submenu
            Menu {
                ForEach(SortOrder.allCases) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        HStack {
                            Text(order.rawValue)
                            if sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Sort By", systemImage: "arrow.up.arrow.down")
            }

            // Grid size submenu
            Menu {
                Button("Small") { gridSize = 80 }
                Button("Medium") { gridSize = 120 }
                Button("Large") { gridSize = 180 }
                Button("Extra Large") { gridSize = 240 }
            } label: {
                Label("Thumbnail Size", systemImage: "square.grid.3x3")
            }
        }
    }
}

// MARK: - Histogram Context Menu

/// Context menu for histogram view
struct HistogramContextMenu: View {
    @Binding var channels: HistogramView.HistogramChannels
    @Binding var style: HistogramView.HistogramStyle

    var body: some View {
        Group {
            // Channel selection
            Menu("Channels") {
                Button {
                    channels = .luminance
                } label: {
                    HStack {
                        Text("Luminance")
                        if channels == .luminance {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button {
                    channels = .rgb
                } label: {
                    HStack {
                        Text("RGB")
                        if channels == .rgb {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button {
                    channels = .all
                } label: {
                    HStack {
                        Text("All Channels")
                        if channels == .all {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            // Style selection
            Menu("Style") {
                Button {
                    style = .filled
                } label: {
                    HStack {
                        Text("Filled")
                        if style == .filled {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button {
                    style = .line
                } label: {
                    HStack {
                        Text("Line")
                        if style == .line {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button {
                    style = .bars
                } label: {
                    HStack {
                        Text("Bars")
                        if style == .bars {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Metadata Context Menu

/// Context menu for metadata fields in inspector
struct MetadataContextMenu: View {
    let fieldName: String
    let value: String
    let onCopy: () -> Void
    let onEdit: (() -> Void)?

    var body: some View {
        Group {
            Button {
                onCopy()
            } label: {
                Label("Copy \(fieldName)", systemImage: "doc.on.doc")
            }

            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Edit \(fieldName)...", systemImage: "pencil")
                }
            }
        }
    }
}

// MARK: - Adjustment Preset Context Menu

/// Context menu for adjustment presets
struct PresetContextMenu: View {
    let preset: AdjustmentPreset
    let onApply: () -> Void
    let onUpdate: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
            Button {
                onApply()
            } label: {
                Label("Apply Preset", systemImage: "checkmark")
            }

            Divider()

            Button {
                onUpdate()
            } label: {
                Label("Update with Current Settings", systemImage: "arrow.triangle.2.circlepath")
            }

            Button {
                onRename()
            } label: {
                Label("Rename...", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Preset", systemImage: "trash")
            }
        }
    }
}

// MARK: - Supporting Types

/// Folder type for organizing albums
struct Folder: Identifiable {
    let id: UUID
    var name: String
    var albums: [Album]
    var subfolders: [Folder]
}

/// AdjustmentPreset type for saved edit settings
struct AdjustmentPreset: Identifiable {
    let id: UUID
    var name: String
    var editState: EditState
    var createdAt: Date
}

// MARK: - View Extensions

extension View {
    /// Applies photo context menu to a view
    func photoContextMenu(
        image: PhotoImage,
        onOpenInDetail: @escaping () -> Void,
        onCompareWith: @escaping () -> Void,
        onShowInFinder: @escaping () -> Void,
        onExport: @escaping () -> Void,
        onCopyAdjustments: @escaping () -> Void,
        onPasteAdjustments: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        self.contextMenu {
            PhotoContextMenu(
                image: image,
                onOpenInDetail: onOpenInDetail,
                onCompareWith: onCompareWith,
                onShowInFinder: onShowInFinder,
                onExport: onExport,
                onCopyAdjustments: onCopyAdjustments,
                onPasteAdjustments: onPasteAdjustments,
                onDelete: onDelete
            )
        }
    }

    /// Applies multi-selection context menu to a view
    func multiPhotoContextMenu(
        images: [PhotoImage],
        onExport: @escaping () -> Void,
        onCopyAdjustments: @escaping () -> Void,
        onPasteAdjustments: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        self.contextMenu {
            MultiPhotoContextMenu(
                images: images,
                onExport: onExport,
                onCopyAdjustments: onCopyAdjustments,
                onPasteAdjustments: onPasteAdjustments,
                onDelete: onDelete
            )
        }
    }
}
