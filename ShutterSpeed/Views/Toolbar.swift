import SwiftUI

/// Main application toolbar
struct MainToolbar: View {
    @Binding var viewMode: ViewMode
    @Binding var gridSize: Double
    @Binding var sortOrder: SortOrder
    @Binding var showFilters: Bool
    @Binding var showInspector: Bool

    let selectedCount: Int
    let totalCount: Int

    let onImport: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Left section - Import/Export
            importExportSection

            Divider()
                .frame(height: 20)

            // View mode picker
            viewModePicker

            Divider()
                .frame(height: 20)

            // Grid size slider (when in grid mode)
            if viewMode == .grid {
                gridSizeSlider
            }

            Spacer()

            // Center - Selection info
            selectionInfo

            Spacer()

            // Sort controls
            sortPicker

            Divider()
                .frame(height: 20)

            // Filter toggle
            filterToggle

            // Inspector toggle
            inspectorToggle
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Import/Export Section

    private var importExportSection: some View {
        HStack(spacing: 8) {
            Button(action: onImport) {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .help("Import photos (Cmd+Shift+I)")

            Button(action: onExport) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(selectedCount == 0)
            .help("Export selected photos (Cmd+E)")
        }
        .buttonStyle(.borderless)
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        Picker("View", selection: $viewMode) {
            Image(systemName: "square.grid.3x3")
                .tag(ViewMode.grid)
                .help("Grid View")
            Image(systemName: "rectangle")
                .tag(ViewMode.detail)
                .help("Detail View")
            Image(systemName: "rectangle.split.2x1")
                .tag(ViewMode.compare)
                .help("Compare View")
        }
        .pickerStyle(.segmented)
        .frame(width: 120)
    }

    // MARK: - Grid Size Slider

    private var gridSizeSlider: some View {
        HStack(spacing: 4) {
            Image(systemName: "photo")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Slider(value: $gridSize, in: 80...300)
                .frame(width: 100)

            Image(systemName: "photo")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Selection Info

    private var selectionInfo: some View {
        Group {
            if selectedCount > 0 {
                Text("\(selectedCount) of \(totalCount) selected")
            } else {
                Text("\(totalCount) photos")
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    // MARK: - Sort Picker

    private var sortPicker: some View {
        Menu {
            ForEach(SortOrder.allCases) { order in
                Button {
                    sortOrder = order
                } label: {
                    HStack {
                        Text(order.displayName)
                        if sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text(sortOrder.displayName)
            }
        }
        .menuStyle(.borderlessButton)
        .frame(width: 120)
    }

    // MARK: - Filter Toggle

    private var filterToggle: some View {
        Button {
            showFilters.toggle()
        } label: {
            Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(showFilters ? .accentColor : .primary)
        .help("Show Filters")
    }

    // MARK: - Inspector Toggle

    private var inspectorToggle: some View {
        Button {
            showInspector.toggle()
        } label: {
            Image(systemName: showInspector ? "sidebar.right" : "sidebar.right")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(showInspector ? .accentColor : .primary)
        .help("Toggle Inspector (Cmd+I)")
    }
}

// MARK: - View Mode

enum ViewMode: String, CaseIterable, Identifiable {
    case grid
    case detail
    case compare

    var id: String { rawValue }
}

// MARK: - Sort Order

enum SortOrder: String, CaseIterable, Identifiable {
    case captureDate
    case captureDateDescending
    case importDate
    case fileName
    case rating
    case fileSize

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .captureDate: return "Date (Oldest)"
        case .captureDateDescending: return "Date (Newest)"
        case .importDate: return "Import Date"
        case .fileName: return "File Name"
        case .rating: return "Rating"
        case .fileSize: return "File Size"
        }
    }
}

// MARK: - Detail Toolbar

struct DetailToolbar: View {
    @Binding var zoomLevel: Double
    @Binding var showHistogram: Bool
    @Binding var showLoupe: Bool
    @Binding var showBefore: Bool

    let canZoomIn: Bool
    let canZoomOut: Bool

    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onZoomFit: () -> Void
    let onZoom100: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Navigation
            HStack(spacing: 4) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
            }
            .buttonStyle(.borderless)

            Divider()
                .frame(height: 20)

            // Zoom controls
            HStack(spacing: 4) {
                Button(action: onZoomOut) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .disabled(!canZoomOut)

                Text("\(Int(zoomLevel * 100))%")
                    .font(.callout.monospacedDigit())
                    .frame(width: 50)

                Button(action: onZoomIn) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .disabled(!canZoomIn)

                Button(action: onZoomFit) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .help("Fit to Window")

                Button(action: onZoom100) {
                    Text("1:1")
                        .font(.caption.bold())
                }
                .help("Actual Size")
            }
            .buttonStyle(.borderless)

            Spacer()

            // View toggles
            HStack(spacing: 8) {
                Toggle(isOn: $showLoupe) {
                    Image(systemName: "magnifyingglass")
                }
                .toggleStyle(.button)
                .help("Show Loupe (L)")

                Toggle(isOn: $showHistogram) {
                    Image(systemName: "chart.bar.fill")
                }
                .toggleStyle(.button)
                .help("Show Histogram")

                Toggle(isOn: $showBefore) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                }
                .toggleStyle(.button)
                .help("Show Before (\\)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

// MARK: - Rating Toolbar

struct RatingToolbar: View {
    @Binding var rating: Int
    @Binding var flag: Flag
    @Binding var colorLabel: ColorLabel

    var body: some View {
        HStack(spacing: 16) {
            // Rating stars
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        rating = rating == star ? 0 : star
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .foregroundStyle(star <= rating ? .yellow : .secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }

            Divider()
                .frame(height: 16)

            // Flag buttons
            HStack(spacing: 4) {
                Button {
                    flag = flag == .pick ? .none : .pick
                } label: {
                    Image(systemName: flag == .pick ? "flag.fill" : "flag")
                        .foregroundStyle(flag == .pick ? .white : .secondary)
                }
                .buttonStyle(.borderless)
                .background(flag == .pick ? Color.green : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Button {
                    flag = flag == .reject ? .none : .reject
                } label: {
                    Image(systemName: flag == .reject ? "xmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(flag == .reject ? .white : .secondary)
                }
                .buttonStyle(.borderless)
                .background(flag == .reject ? Color.red : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Divider()
                .frame(height: 16)

            // Color labels
            HStack(spacing: 2) {
                ForEach(ColorLabel.allCases.filter { $0 != .none }, id: \.self) { color in
                    Button {
                        colorLabel = colorLabel == color ? .none : color
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 14, height: 14)
                            .overlay {
                                if colorLabel == color {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

#Preview {
    VStack(spacing: 0) {
        MainToolbar(
            viewMode: .constant(.grid),
            gridSize: .constant(150),
            sortOrder: .constant(.captureDateDescending),
            showFilters: .constant(false),
            showInspector: .constant(true),
            selectedCount: 5,
            totalCount: 100,
            onImport: {},
            onExport: {}
        )

        Divider()

        DetailToolbar(
            zoomLevel: .constant(1.0),
            showHistogram: .constant(true),
            showLoupe: .constant(false),
            showBefore: .constant(false),
            canZoomIn: true,
            canZoomOut: true,
            onZoomIn: {},
            onZoomOut: {},
            onZoomFit: {},
            onZoom100: {},
            onPrevious: {},
            onNext: {}
        )
    }
}
