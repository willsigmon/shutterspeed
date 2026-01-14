import SwiftUI

/// Right-side inspector panel showing metadata and adjustments
struct InspectorPanel: View {
    let image: PhotoImage?
    @Binding var editState: EditState?
    @State private var selectedTab: InspectorTab = .info

    enum InspectorTab: String, CaseIterable {
        case info = "Info"
        case adjust = "Adjust"
        case metadata = "Metadata"
        case keywords = "Keywords"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            // Content
            if let image = image {
                ScrollView {
                    switch selectedTab {
                    case .info:
                        InfoTab(image: image)
                    case .adjust:
                        AdjustTab(image: image, editState: $editState)
                    case .metadata:
                        MetadataTab(image: image)
                    case .keywords:
                        KeywordsTab(image: image)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "photo",
                    description: Text("Select an image to view details")
                )
            }
        }
        .frame(width: 280)
        .background(.background)
    }
}

// MARK: - Info Tab

struct InfoTab: View {
    let image: PhotoImage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Quick info section
            GroupBox("Quick Info") {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Name", value: image.fileName)
                    InfoRow(label: "Size", value: formattedFileSize)
                    InfoRow(label: "Dimensions", value: dimensionsString)
                    InfoRow(label: "Date", value: formattedDate)
                }
            }

            // Rating
            GroupBox("Rating") {
                HStack {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= image.rating ? "star.fill" : "star")
                            .foregroundStyle(star <= image.rating ? .yellow : .secondary)
                            .onTapGesture {
                                // TODO: Update rating
                            }
                    }
                    Spacer()
                }
            }

            // Flag & Color
            GroupBox("Organization") {
                HStack {
                    // Flags
                    Button(action: {}) {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(image.flag == .pick ? .green : .secondary)
                    }
                    .buttonStyle(.borderless)

                    Button(action: {}) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(image.flag == .reject ? .red : .secondary)
                    }
                    .buttonStyle(.borderless)

                    Divider()
                        .frame(height: 16)

                    // Color labels
                    ForEach(ColorLabel.allCases.filter { $0 != .none }, id: \.self) { color in
                        Circle()
                            .fill(color.color)
                            .frame(width: 14, height: 14)
                            .overlay {
                                if image.colorLabel == color {
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                }
                            }
                            .onTapGesture {
                                // TODO: Update color label
                            }
                    }

                    Spacer()
                }
            }

            // Camera info
            if let camera = cameraInfo {
                GroupBox("Camera") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(camera)
                            .font(.callout)
                        if let lens = image.metadata.lensModel {
                            Text(lens)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Exposure info
            GroupBox("Exposure") {
                HStack(spacing: 16) {
                    ExposureValue(label: "ISO", value: image.metadata.iso.map { "\($0)" })
                    ExposureValue(label: "f/", value: image.metadata.aperture.map { String(format: "%.1f", $0) })
                    ExposureValue(label: "", value: image.metadata.shutterSpeed)
                    ExposureValue(label: "", value: image.metadata.focalLength.map { "\(Int($0))mm" })
                }
            }

            Spacer()
        }
        .padding()
    }

    private var formattedFileSize: String {
        guard let size = image.fileSize else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private var dimensionsString: String {
        guard let w = image.width, let h = image.height else { return "Unknown" }
        let mp = Double(w * h) / 1_000_000
        return "\(w) × \(h) (\(String(format: "%.1f", mp)) MP)"
    }

    private var formattedDate: String {
        guard let date = image.captureDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var cameraInfo: String? {
        if let make = image.metadata.cameraMake, let model = image.metadata.cameraModel {
            return "\(make) \(model)"
        }
        return image.metadata.cameraModel ?? image.metadata.cameraMake
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.callout)
    }
}

struct ExposureValue: View {
    let label: String
    let value: String?

    var body: some View {
        VStack(spacing: 2) {
            Text(value ?? "--")
                .font(.callout.monospacedDigit())
            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Adjust Tab

struct AdjustTab: View {
    let image: PhotoImage
    @Binding var editState: EditState?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Light section
            AdjustmentSection(title: "Light") {
                AdjustmentSlider(label: "Exposure", value: binding(for: .exposure), range: -5...5, defaultValue: 0)
                AdjustmentSlider(label: "Contrast", value: binding(for: .contrast), range: -100...100, defaultValue: 0)
                AdjustmentSlider(label: "Highlights", value: binding(for: .highlights), range: -100...100, defaultValue: 0)
                AdjustmentSlider(label: "Shadows", value: binding(for: .shadows), range: -100...100, defaultValue: 0)
                AdjustmentSlider(label: "Whites", value: binding(for: .whites), range: -100...100, defaultValue: 0)
                AdjustmentSlider(label: "Blacks", value: binding(for: .blacks), range: -100...100, defaultValue: 0)
            }

            // White Balance section
            AdjustmentSection(title: "White Balance") {
                AdjustmentSlider(label: "Temperature", value: binding(for: .temperature), range: 2000...50000, defaultValue: 6500)
                AdjustmentSlider(label: "Tint", value: binding(for: .tint), range: -150...150, defaultValue: 0)
            }

            // Color section
            AdjustmentSection(title: "Color") {
                AdjustmentSlider(label: "Saturation", value: binding(for: .saturation), range: -100...100, defaultValue: 0)
                AdjustmentSlider(label: "Vibrance", value: binding(for: .vibrance), range: -100...100, defaultValue: 0)
            }

            // Detail section
            AdjustmentSection(title: "Detail") {
                AdjustmentSlider(label: "Sharpening", value: bindingForParam(.sharpening, param: "amount"), range: 0...100, defaultValue: 0)
                AdjustmentSlider(label: "Noise Reduction", value: bindingForParam(.noiseReduction, param: "luminance"), range: 0...100, defaultValue: 0)
            }

            // Effects section
            AdjustmentSection(title: "Effects") {
                AdjustmentSlider(label: "Vignette", value: bindingForParam(.vignette, param: "amount"), range: -100...100, defaultValue: 0)
            }

            // Reset button
            Button("Reset All Adjustments") {
                editState = EditState(imageID: image.id)
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .padding(.top)

            Spacer()
        }
        .padding()
    }

    private func binding(for type: AdjustmentType) -> Binding<Double> {
        bindingForParam(type, param: "value")
    }

    private func bindingForParam(_ type: AdjustmentType, param: String) -> Binding<Double> {
        Binding(
            get: {
                editState?.adjustments.first { $0.type == type }?.parameters[param] ?? type.defaultParameters[param] ?? 0
            },
            set: { newValue in
                if editState == nil {
                    editState = EditState(imageID: image.id)
                }

                if let index = editState?.adjustments.firstIndex(where: { $0.type == type }) {
                    editState?.adjustments[index].parameters[param] = newValue
                } else {
                    var adjustment = Adjustment(type: type, parameters: type.defaultParameters)
                    adjustment.parameters[param] = newValue
                    editState?.adjustments.append(adjustment)
                }
            }
        )
    }
}

struct AdjustmentSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 8) {
                content()
            }
            .padding(.top, 4)
        } label: {
            Text(title)
                .font(.headline)
        }
    }
}

struct AdjustmentSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(label)
                    .font(.callout)
                Spacer()
                Text(formattedValue)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }

            Slider(value: $value, in: range)
                .onDoubleClick {
                    value = defaultValue
                }
        }
    }

    private var formattedValue: String {
        if range.upperBound > 1000 {
            return "\(Int(value))K"
        } else if range.upperBound <= 5 {
            return String(format: "%.2f", value)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Metadata Tab

struct MetadataTab: View {
    let image: PhotoImage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // File info
            GroupBox("File") {
                VStack(alignment: .leading, spacing: 6) {
                    MetadataRow(label: "Name", value: image.fileName)
                    MetadataRow(label: "Path", value: image.filePath.path)
                    MetadataRow(label: "Size", value: formattedSize)
                    MetadataRow(label: "Type", value: image.filePath.pathExtension.uppercased())
                }
            }

            // Camera info
            GroupBox("Camera") {
                VStack(alignment: .leading, spacing: 6) {
                    MetadataRow(label: "Make", value: image.metadata.cameraMake ?? "--")
                    MetadataRow(label: "Model", value: image.metadata.cameraModel ?? "--")
                    MetadataRow(label: "Lens", value: image.metadata.lensModel ?? "--")
                }
            }

            // Exposure
            GroupBox("Exposure") {
                VStack(alignment: .leading, spacing: 6) {
                    MetadataRow(label: "ISO", value: image.metadata.iso.map { "\($0)" } ?? "--")
                    MetadataRow(label: "Aperture", value: image.metadata.aperture.map { "f/\($0)" } ?? "--")
                    MetadataRow(label: "Shutter", value: image.metadata.shutterSpeed ?? "--")
                    MetadataRow(label: "Focal Length", value: image.metadata.focalLength.map { "\(Int($0))mm" } ?? "--")
                }
            }

            // GPS
            if let lat = image.metadata.gpsLatitude, let lon = image.metadata.gpsLongitude {
                GroupBox("Location") {
                    VStack(alignment: .leading, spacing: 6) {
                        MetadataRow(label: "Latitude", value: String(format: "%.6f", lat))
                        MetadataRow(label: "Longitude", value: String(format: "%.6f", lon))
                        Button("Show in Maps") {
                            // TODO: Open in Maps
                        }
                        .buttonStyle(.link)
                    }
                }
            }

            // Dates
            GroupBox("Dates") {
                VStack(alignment: .leading, spacing: 6) {
                    MetadataRow(label: "Captured", value: formattedDate(image.captureDate))
                    MetadataRow(label: "Imported", value: formattedDate(image.importDate))
                }
            }

            Spacer()
        }
        .padding()
    }

    private var formattedSize: String {
        guard let size = image.fileSize else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Keywords Tab

struct KeywordsTab: View {
    let image: PhotoImage
    @State private var newKeyword = ""
    @State private var keywords: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Add keyword
            HStack {
                TextField("Add keyword...", text: $newKeyword)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addKeyword()
                    }
                Button(action: addKeyword) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(newKeyword.isEmpty)
            }

            // Keywords list
            if keywords.isEmpty {
                ContentUnavailableView(
                    "No Keywords",
                    systemImage: "tag",
                    description: Text("Add keywords to organize your photos")
                )
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(keywords, id: \.self) { keyword in
                        KeywordChip(keyword: keyword) {
                            removeKeyword(keyword)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            keywords = image.keywords
        }
    }

    private func addKeyword() {
        let keyword = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty, !keywords.contains(keyword) else { return }
        keywords.append(keyword)
        newKeyword = ""
        // TODO: Save to database
    }

    private func removeKeyword(_ keyword: String) {
        keywords.removeAll { $0 == keyword }
        // TODO: Save to database
    }
}

struct KeywordChip: View {
    let keyword: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(keyword)
                .font(.callout)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary)
        .clipShape(Capsule())
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangement(for: subviews, in: proposal.width ?? 0)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangement(for: subviews, in: bounds.width)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangement(for subviews: Subviews, in width: CGFloat) -> (positions: [CGPoint], height: CGFloat) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, y + rowHeight)
    }
}

// MARK: - Double Click Modifier

extension View {
    func onDoubleClick(perform action: @escaping () -> Void) -> some View {
        self.gesture(
            TapGesture(count: 2)
                .onEnded { _ in action() }
        )
    }
}

#Preview {
    InspectorPanel(
        image: nil,
        editState: .constant(nil)
    )
}
