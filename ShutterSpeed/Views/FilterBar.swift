import SwiftUI

/// Quick filter bar for grid view
struct FilterBar: View {
    @Binding var activeFilters: FilterState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Rating filter
                Menu {
                    Button("Any Rating") {
                        activeFilters.minRating = nil
                    }
                    Divider()
                    ForEach(1...5, id: \.self) { rating in
                        Button {
                            activeFilters.minRating = rating
                        } label: {
                            HStack {
                                ForEach(1...rating, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                }
                                Text("or higher")
                            }
                        }
                    }
                } label: {
                    FilterChip(
                        icon: "star.fill",
                        label: ratingLabel,
                        isActive: activeFilters.minRating != nil
                    )
                }

                // Flag filter
                Menu {
                    Button("Any Flag") {
                        activeFilters.flag = nil
                    }
                    Divider()
                    Button {
                        activeFilters.flag = .pick
                    } label: {
                        Label("Picked", systemImage: "flag.fill")
                    }
                    Button {
                        activeFilters.flag = .reject
                    } label: {
                        Label("Rejected", systemImage: "xmark.circle.fill")
                    }
                    Button {
                        activeFilters.flag = .none
                    } label: {
                        Label("Unflagged", systemImage: "flag")
                    }
                } label: {
                    FilterChip(
                        icon: flagIcon,
                        label: flagLabel,
                        isActive: activeFilters.flag != nil
                    )
                }

                // Color label filter
                Menu {
                    Button("Any Color") {
                        activeFilters.colorLabel = nil
                    }
                    Divider()
                    ForEach(ColorLabel.allCases.filter { $0 != .none }, id: \.self) { color in
                        Button {
                            activeFilters.colorLabel = color
                        } label: {
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 12, height: 12)
                                Text(color.name)
                            }
                        }
                    }
                } label: {
                    FilterChip(
                        icon: "circle.fill",
                        iconColor: activeFilters.colorLabel?.color,
                        label: colorLabel,
                        isActive: activeFilters.colorLabel != nil
                    )
                }

                // File type filter
                Menu {
                    Button("All Types") {
                        activeFilters.fileType = nil
                    }
                    Divider()
                    Button("RAW Only") {
                        activeFilters.fileType = .raw
                    }
                    Button("JPEG Only") {
                        activeFilters.fileType = .jpeg
                    }
                    Button("HEIC Only") {
                        activeFilters.fileType = .heic
                    }
                } label: {
                    FilterChip(
                        icon: "doc.fill",
                        label: fileTypeLabel,
                        isActive: activeFilters.fileType != nil
                    )
                }

                // Camera filter
                if !availableCameras.isEmpty {
                    Menu {
                        Button("All Cameras") {
                            activeFilters.camera = nil
                        }
                        Divider()
                        ForEach(availableCameras, id: \.self) { camera in
                            Button(camera) {
                                activeFilters.camera = camera
                            }
                        }
                    } label: {
                        FilterChip(
                            icon: "camera.fill",
                            label: activeFilters.camera ?? "Camera",
                            isActive: activeFilters.camera != nil
                        )
                    }
                }

                // Date filter
                Menu {
                    Button("Any Date") {
                        activeFilters.dateRange = nil
                    }
                    Divider()
                    Button("Today") {
                        activeFilters.dateRange = .today
                    }
                    Button("Last 7 Days") {
                        activeFilters.dateRange = .lastWeek
                    }
                    Button("Last 30 Days") {
                        activeFilters.dateRange = .lastMonth
                    }
                    Button("This Year") {
                        activeFilters.dateRange = .thisYear
                    }
                } label: {
                    FilterChip(
                        icon: "calendar",
                        label: dateLabel,
                        isActive: activeFilters.dateRange != nil
                    )
                }

                // Clear all
                if activeFilters.hasActiveFilters {
                    Button("Clear All") {
                        activeFilters = FilterState()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Labels

    private var ratingLabel: String {
        if let min = activeFilters.minRating {
            return "\(min)+ Stars"
        }
        return "Rating"
    }

    private var flagLabel: String {
        switch activeFilters.flag {
        case .pick: return "Picked"
        case .reject: return "Rejected"
        case .none: return "Unflagged"
        case nil: return "Flag"
        }
    }

    private var flagIcon: String {
        switch activeFilters.flag {
        case .pick: return "flag.fill"
        case .reject: return "xmark.circle.fill"
        default: return "flag"
        }
    }

    private var colorLabel: String {
        activeFilters.colorLabel?.name ?? "Color"
    }

    private var fileTypeLabel: String {
        activeFilters.fileType?.rawValue ?? "Type"
    }

    private var dateLabel: String {
        switch activeFilters.dateRange {
        case .today: return "Today"
        case .lastWeek: return "Last 7 Days"
        case .lastMonth: return "Last 30 Days"
        case .thisYear: return "This Year"
        case .custom: return "Custom"
        case nil: return "Date"
        }
    }

    // TODO: Populate from actual library data
    private var availableCameras: [String] {
        []
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let icon: String
    var iconColor: Color? = nil
    let label: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(iconColor ?? (isActive ? .white : .secondary))
            Text(label)
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isActive ? Color.accentColor : Color.secondary.opacity(0.2))
        .foregroundStyle(isActive ? .white : .primary)
        .clipShape(Capsule())
    }
}

// MARK: - Filter State

struct FilterState {
    var minRating: Int?
    var flag: Flag?
    var colorLabel: ColorLabel?
    var fileType: FileTypeFilter?
    var camera: String?
    var lens: String?
    var dateRange: DateRangeFilter?
    var keyword: String?

    var hasActiveFilters: Bool {
        minRating != nil ||
        flag != nil ||
        colorLabel != nil ||
        fileType != nil ||
        camera != nil ||
        lens != nil ||
        dateRange != nil ||
        keyword != nil
    }

    enum FileTypeFilter: String {
        case raw = "RAW"
        case jpeg = "JPEG"
        case heic = "HEIC"
        case png = "PNG"
        case tiff = "TIFF"
    }

    enum DateRangeFilter {
        case today
        case lastWeek
        case lastMonth
        case thisYear
        case custom(start: Date, end: Date)

        var dateRange: (start: Date, end: Date) {
            let now = Date()
            let calendar = Calendar.current

            switch self {
            case .today:
                let start = calendar.startOfDay(for: now)
                return (start, now)
            case .lastWeek:
                let start = calendar.date(byAdding: .day, value: -7, to: now)!
                return (start, now)
            case .lastMonth:
                let start = calendar.date(byAdding: .day, value: -30, to: now)!
                return (start, now)
            case .thisYear:
                let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
                return (start, now)
            case .custom(let start, let end):
                return (start, end)
            }
        }
    }

    func matches(_ image: PhotoImage) -> Bool {
        // Rating filter
        if let minRating, image.rating < minRating {
            return false
        }

        // Flag filter
        if let flag, image.flag != flag {
            return false
        }

        // Color label filter
        if let colorLabel, image.colorLabel != colorLabel {
            return false
        }

        // File type filter
        if let fileType {
            let ext = image.filePath.pathExtension.lowercased()
            switch fileType {
            case .raw:
                if !RAWProcessor.rawExtensions.contains(ext) { return false }
            case .jpeg:
                if ext != "jpg" && ext != "jpeg" { return false }
            case .heic:
                if ext != "heic" && ext != "heif" { return false }
            case .png:
                if ext != "png" { return false }
            case .tiff:
                if ext != "tiff" && ext != "tif" { return false }
            }
        }

        // Camera filter
        if let camera, image.metadata.cameraModel != camera {
            return false
        }

        // Date filter
        if let dateRange, let captureDate = image.captureDate {
            let range = dateRange.dateRange
            if captureDate < range.start || captureDate > range.end {
                return false
            }
        }

        // Keyword filter
        if let keyword, !keyword.isEmpty {
            if !image.keywords.contains(where: { $0.localizedCaseInsensitiveContains(keyword) }) {
                return false
            }
        }

        return true
    }
}

#Preview {
    FilterBar(activeFilters: .constant(FilterState()))
}
