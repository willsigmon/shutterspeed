import SwiftUI

/// Export options and progress dialog
struct ExportDialog: View {
    let images: [PhotoImage]
    let edits: [UUID: EditState]
    let library: PhotoLibrary

    @Environment(\.dismiss) private var dismiss

    @State private var settings = ExportService.ExportSettings()
    @State private var destination: URL?
    @State private var isExporting = false
    @State private var progress: Double = 0
    @State private var currentFile = ""
    @State private var result: ExportService.ExportResult?

    var body: some View {
        VStack(spacing: 20) {
            if isExporting {
                exportProgressView
            } else if let result {
                exportCompleteView(result)
            } else {
                exportOptionsView
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    // MARK: - Options View

    private var exportOptionsView: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.title)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text("Export Photos")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("\(images.count) photo\(images.count == 1 ? "" : "s") selected")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Form {
                // Format
                Section("Format") {
                    Picker("File Format", selection: $settings.format) {
                        ForEach(ExportService.ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }

                    if settings.format.supportsQuality {
                        HStack {
                            Text("Quality")
                            Slider(value: $settings.quality, in: 0.1...1.0)
                            Text("\(Int(settings.quality * 100))%")
                                .monospacedDigit()
                                .frame(width: 40)
                        }
                    }
                }

                // Size
                Section("Size") {
                    Picker("Output Size", selection: Binding(
                        get: { settings.maxSize == nil ? 0 : 1 },
                        set: { settings.maxSize = $0 == 0 ? nil : CGSize(width: 2048, height: 2048) }
                    )) {
                        Text("Original").tag(0)
                        Text("Custom").tag(1)
                    }

                    if settings.maxSize != nil {
                        HStack {
                            TextField("Max Width", value: Binding(
                                get: { Int(settings.maxSize?.width ?? 2048) },
                                set: { settings.maxSize = CGSize(width: CGFloat($0), height: settings.maxSize?.height ?? 2048) }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)

                            Text("×")

                            TextField("Max Height", value: Binding(
                                get: { Int(settings.maxSize?.height ?? 2048) },
                                set: { settings.maxSize = CGSize(width: settings.maxSize?.width ?? 2048, height: CGFloat($0)) }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)

                            Text("pixels")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Metadata
                Section("Metadata") {
                    Toggle("Include metadata", isOn: $settings.includeMetadata)
                    Toggle("Write XMP sidecar", isOn: $settings.writeXMP)
                }

                // Naming
                Section("File Naming") {
                    Picker("Naming", selection: Binding(
                        get: { namingSchemeIndex },
                        set: { updateNamingScheme($0) }
                    )) {
                        Text("Original filename").tag(0)
                        Text("Date and time").tag(1)
                        Text("Sequential").tag(2)
                    }
                }

                // Destination
                Section("Destination") {
                    HStack {
                        if let destination {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.secondary)
                            Text(destination.path)
                                .lineLimit(1)
                                .truncationMode(.head)
                        } else {
                            Text("No destination selected")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Choose...") {
                            selectDestination()
                        }
                    }
                }
            }
            .formStyle(.grouped)

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Export") {
                    Task {
                        await startExport()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(destination == nil)
            }
        }
    }

    // MARK: - Progress View

    private var exportProgressView: some View {
        VStack(spacing: 20) {
            Text("Exporting...")
                .font(.title2)
                .fontWeight(.semibold)

            ProgressView(value: progress) {
                HStack {
                    Text(currentFile)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .monospacedDigit()
                }
                .font(.callout)
            }

            Button("Cancel") {
                // TODO: Cancel export
            }
        }
    }

    // MARK: - Complete View

    private func exportCompleteView(_ result: ExportService.ExportResult) -> some View {
        VStack(spacing: 20) {
            Image(systemName: result.failedFiles.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(result.failedFiles.isEmpty ? .green : .yellow)

            Text("Export Complete")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                HStack {
                    Text("Exported:")
                    Spacer()
                    Text("\(result.exportedFiles.count) files")
                }

                if !result.failedFiles.isEmpty {
                    HStack {
                        Text("Failed:")
                        Spacer()
                        Text("\(result.failedFiles.count) files")
                            .foregroundStyle(.red)
                    }
                }

                HStack {
                    Text("Total size:")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: result.totalSize, countStyle: .file))
                }

                HStack {
                    Text("Duration:")
                    Spacer()
                    Text(String(format: "%.1f seconds", result.duration))
                }
            }
            .font(.callout)

            HStack {
                Button("Show in Finder") {
                    if let destination {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: destination.path)
                    }
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - Helpers

    private var namingSchemeIndex: Int {
        switch settings.namingScheme {
        case .original: return 0
        case .datetime: return 1
        case .sequential: return 2
        case .custom: return 0
        }
    }

    private func updateNamingScheme(_ index: Int) {
        switch index {
        case 0: settings.namingScheme = .original
        case 1: settings.namingScheme = .datetime
        case 2: settings.namingScheme = .sequential(prefix: "Photo_", start: 1)
        default: break
        }
    }

    private func selectDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose export destination"

        if panel.runModal() == .OK {
            destination = panel.url
        }
    }

    private func startExport() async {
        guard let destination else { return }

        await MainActor.run {
            isExporting = true
        }

        let exportResult = try? await ExportService.shared.export(
            images: images,
            edits: edits,
            to: destination,
            settings: settings
        ) { prog, file in
            Task { @MainActor in
                progress = prog
                currentFile = file
            }
        }

        await MainActor.run {
            isExporting = false
            result = exportResult
        }
    }
}

#Preview {
    ExportDialog(
        images: [],
        edits: [:],
        library: PhotoLibrary.preview
    )
}
