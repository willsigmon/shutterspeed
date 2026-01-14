import SwiftUI

/// Import progress dialog
struct ImportProgressView: View {
    @ObservedObject var importService: ObservableImportService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .font(.title)
                    .foregroundStyle(.tint)
                Text("Importing Photos")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Progress
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: importService.progress) {
                    HStack {
                        Text(importService.currentFile)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text("\(importService.importedCount) imported")
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }

                if importService.failedCount > 0 {
                    Text("\(importService.failedCount) failed")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Error list (if any)
            if !importService.errors.isEmpty {
                GroupBox("Errors") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(importService.errors) { error in
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.yellow)
                                    VStack(alignment: .leading) {
                                        Text(error.fileName)
                                            .font(.callout)
                                        Text(error.error)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
            }

            // Actions
            HStack {
                if importService.isImporting {
                    Button("Cancel") {
                        // TODO: Cancel import
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                } else {
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

/// Observable wrapper for ImportService
@Observable
class ObservableImportService: ObservableObject {
    private let service = ImportService()

    var isImporting: Bool { service.isImporting }
    var progress: Double { service.progress }
    var currentFile: String { service.currentFile }
    var importedCount: Int { service.importedCount }
    var failedCount: Int { service.failedCount }
    var errors: [ImportService.ImportError] { service.errors }

    func importPhotos(from urls: [URL], to library: PhotoLibrary, copyToLibrary: Bool = true) async -> ImportService.ImportResult {
        await service.importPhotos(from: urls, to: library, copyToLibrary: copyToLibrary)
    }
}

// MARK: - Import Options Sheet

struct ImportOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var copyToLibrary = true
    @State private var organizeByDate = true
    @State private var detectDuplicates = true
    @State private var importRAWplusJPEG = false
    @State private var selectedFolders: [URL] = []

    let onImport: ([URL], Bool) -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Import Options")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                // File handling
                Section("File Handling") {
                    Toggle("Copy files to library", isOn: $copyToLibrary)
                    Toggle("Organize by date", isOn: $organizeByDate)
                        .disabled(!copyToLibrary)
                    Toggle("Skip duplicates", isOn: $detectDuplicates)
                }

                // RAW options
                Section("RAW Files") {
                    Toggle("Import RAW+JPEG as single image", isOn: $importRAWplusJPEG)
                }
            }
            .formStyle(.grouped)

            // Selected folders
            if !selectedFolders.isEmpty {
                GroupBox("Selected") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(selectedFolders, id: \.self) { url in
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.secondary)
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                Spacer()
                                Button(action: {
                                    selectedFolders.removeAll { $0 == url }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }

            // Actions
            HStack {
                Button("Add Folder...") {
                    selectFolder()
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Import") {
                    onImport(selectedFolders, copyToLibrary)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedFolders.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 450)
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select files or folders to import"

        if panel.runModal() == .OK {
            selectedFolders.append(contentsOf: panel.urls)
        }
    }
}

#Preview("Import Progress") {
    ImportProgressView(importService: ObservableImportService())
}

#Preview("Import Options") {
    ImportOptionsSheet { urls, copy in
        print("Import \(urls.count) items, copy: \(copy)")
    }
}
