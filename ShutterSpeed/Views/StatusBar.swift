import SwiftUI

/// Bottom status bar showing library info and current operation status
struct StatusBar: View {
    let libraryName: String
    let imageCount: Int
    let selectedCount: Int
    let currentImage: PhotoImage?
    let isLoading: Bool
    let loadingMessage: String?
    let diskUsage: Int64?

    var body: some View {
        HStack(spacing: 16) {
            // Library info
            libraryInfoSection

            Divider()
                .frame(height: 12)

            // Current image info
            if let image = currentImage {
                currentImageSection(image)
            }

            Spacer()

            // Loading indicator
            if isLoading {
                loadingSection
            }

            // Disk usage
            if let usage = diskUsage {
                diskUsageSection(usage)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(height: 24)
        .background(.bar)
    }

    // MARK: - Library Info

    private var libraryInfoSection: some View {
        HStack(spacing: 4) {
            Image(systemName: "photo.on.rectangle")
            Text(libraryName)
                .fontWeight(.medium)
            Text("\(imageCount) photos")
        }
    }

    // MARK: - Current Image Info

    private func currentImageSection(_ image: PhotoImage) -> some View {
        HStack(spacing: 8) {
            // Filename
            Text(image.fileName)
                .fontWeight(.medium)

            // Dimensions
            if let width = image.metadata.pixelWidth,
               let height = image.metadata.pixelHeight {
                Text("\(width) × \(height)")
            }

            // File type badge
            if RAWProcessor.isRAWFile(image.filePath) {
                Text("RAW")
                    .font(.caption2.bold())
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            // Camera info
            if let camera = image.metadata.cameraModel {
                Text(camera)
            }

            // Capture settings
            captureSettingsView(image.metadata)
        }
    }

    private func captureSettingsView(_ metadata: ImageMetadata) -> some View {
        HStack(spacing: 4) {
            if let aperture = metadata.aperture {
                Text("f/\(String(format: "%.1f", aperture))")
            }
            if let shutter = metadata.shutterSpeed {
                Text(formatShutterSpeed(shutter))
            }
            if let iso = metadata.iso {
                Text("ISO \(iso)")
            }
            if let focal = metadata.focalLength {
                Text("\(Int(focal))mm")
            }
        }
    }

    private func formatShutterSpeed(_ speed: Double) -> String {
        if speed >= 1 {
            return "\(Int(speed))s"
        } else {
            let denominator = Int(round(1 / speed))
            return "1/\(denominator)"
        }
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)

            if let message = loadingMessage {
                Text(message)
            }
        }
    }

    // MARK: - Disk Usage

    private func diskUsageSection(_ bytes: Int64) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "internaldrive")
            Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
        }
    }
}

// MARK: - Import Progress Status Bar

struct ImportProgressStatusBar: View {
    let currentFile: String
    let progress: Double
    let imported: Int
    let total: Int
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Progress indicator
            ProgressView(value: progress)
                .frame(width: 100)

            // Status text
            VStack(alignment: .leading, spacing: 0) {
                Text("Importing \(imported) of \(total)")
                    .font(.caption)
                    .fontWeight(.medium)

                Text(currentFile)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Percentage
            Text("\(Int(progress * 100))%")
                .font(.caption.monospacedDigit())
                .fontWeight(.medium)

            // Cancel button
            Button("Cancel", action: onCancel)
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

// MARK: - Export Progress Status Bar

struct ExportProgressStatusBar: View {
    let currentFile: String
    let progress: Double
    let exported: Int
    let total: Int
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Progress indicator
            ProgressView(value: progress)
                .frame(width: 100)

            // Status text
            VStack(alignment: .leading, spacing: 0) {
                Text("Exporting \(exported) of \(total)")
                    .font(.caption)
                    .fontWeight(.medium)

                Text(currentFile)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Percentage
            Text("\(Int(progress * 100))%")
                .font(.caption.monospacedDigit())
                .fontWeight(.medium)

            // Cancel button
            Button("Cancel", action: onCancel)
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

// MARK: - Processing Status Bar

struct ProcessingStatusBar: View {
    let operation: String
    let progress: Double?
    let isIndeterminate: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isIndeterminate {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            } else if let progress {
                ProgressView(value: progress)
                    .frame(width: 100)
            }

            Text(operation)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let progress, !isIndeterminate {
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

#Preview {
    VStack(spacing: 0) {
        StatusBar(
            libraryName: "My Photos",
            imageCount: 1234,
            selectedCount: 5,
            currentImage: nil,
            isLoading: false,
            loadingMessage: nil,
            diskUsage: 1_500_000_000
        )

        Divider()

        ImportProgressStatusBar(
            currentFile: "DSC_0001.NEF",
            progress: 0.45,
            imported: 45,
            total: 100,
            onCancel: {}
        )

        Divider()

        ProcessingStatusBar(
            operation: "Generating thumbnails...",
            progress: 0.75,
            isIndeterminate: false
        )
    }
}
