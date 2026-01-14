import SwiftUI

/// Application settings/preferences view
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ImportSettingsView()
                .tabItem {
                    Label("Import", systemImage: "square.and.arrow.down")
                }

            EditingSettingsView()
                .tabItem {
                    Label("Editing", systemImage: "slider.horizontal.3")
                }

            ExportSettingsView()
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

            PerformanceSettingsView()
                .tabItem {
                    Label("Performance", systemImage: "speedometer")
                }

            KeyboardSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 550, height: 400)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("defaultLibraryPath") private var defaultLibraryPath = ""
    @AppStorage("showWelcomeOnLaunch") private var showWelcomeOnLaunch = true
    @AppStorage("autoSaveEdits") private var autoSaveEdits = true
    @AppStorage("confirmBeforeDelete") private var confirmBeforeDelete = true
    @AppStorage("showRawBadge") private var showRawBadge = true
    @AppStorage("colorScheme") private var colorScheme = "system"

    var body: some View {
        Form {
            Section("Library") {
                HStack {
                    TextField("Default Library Location", text: $defaultLibraryPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose...") {
                        chooseDefaultLibraryPath()
                    }
                }

                Toggle("Show welcome screen on launch", isOn: $showWelcomeOnLaunch)
            }

            Section("Editing") {
                Toggle("Auto-save edits", isOn: $autoSaveEdits)
                Toggle("Confirm before deleting photos", isOn: $confirmBeforeDelete)
            }

            Section("Appearance") {
                Picker("Theme", selection: $colorScheme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.radioGroup)

                Toggle("Show RAW badge on thumbnails", isOn: $showRawBadge)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func chooseDefaultLibraryPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose default library location"

        if panel.runModal() == .OK, let url = panel.url {
            defaultLibraryPath = url.path
        }
    }
}

// MARK: - Import Settings

struct ImportSettingsView: View {
    @AppStorage("copyToLibraryByDefault") private var copyToLibraryByDefault = true
    @AppStorage("organizeByDate") private var organizeByDate = true
    @AppStorage("dateOrganizationFormat") private var dateOrganizationFormat = "YYYY/MM/DD"
    @AppStorage("skipDuplicates") private var skipDuplicates = true
    @AppStorage("generateThumbnailsOnImport") private var generateThumbnailsOnImport = true
    @AppStorage("extractMetadataOnImport") private var extractMetadataOnImport = true
    @AppStorage("applyDevelopSettings") private var applyDevelopSettings = false

    var body: some View {
        Form {
            Section("File Handling") {
                Toggle("Copy files to library by default", isOn: $copyToLibraryByDefault)
                Toggle("Skip duplicate files", isOn: $skipDuplicates)
            }

            Section("Organization") {
                Toggle("Organize by date", isOn: $organizeByDate)

                if organizeByDate {
                    Picker("Date format", selection: $dateOrganizationFormat) {
                        Text("YYYY/MM/DD").tag("YYYY/MM/DD")
                        Text("YYYY/MM").tag("YYYY/MM")
                        Text("YYYY-MM-DD").tag("YYYY-MM-DD")
                        Text("YYYY/Month/DD").tag("YYYY/Month/DD")
                    }
                }
            }

            Section("Processing") {
                Toggle("Generate thumbnails on import", isOn: $generateThumbnailsOnImport)
                Toggle("Extract metadata on import", isOn: $extractMetadataOnImport)
                Toggle("Apply camera develop settings", isOn: $applyDevelopSettings)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Editing Settings

struct EditingSettingsView: View {
    @AppStorage("defaultWhiteBalance") private var defaultWhiteBalance = "AsShot"
    @AppStorage("autoLensCorrection") private var autoLensCorrection = true
    @AppStorage("chromaNoiseReduction") private var chromaNoiseReduction = true
    @AppStorage("preserveRawColorProfile") private var preserveRawColorProfile = true
    @AppStorage("undoLevels") private var undoLevels = 50
    @AppStorage("enableGpuAcceleration") private var enableGpuAcceleration = true

    var body: some View {
        Form {
            Section("RAW Processing") {
                Picker("Default white balance", selection: $defaultWhiteBalance) {
                    Text("As Shot").tag("AsShot")
                    Text("Auto").tag("Auto")
                    Text("Daylight").tag("Daylight")
                    Text("Cloudy").tag("Cloudy")
                    Text("Shade").tag("Shade")
                    Text("Tungsten").tag("Tungsten")
                    Text("Fluorescent").tag("Fluorescent")
                    Text("Flash").tag("Flash")
                }

                Toggle("Auto lens correction", isOn: $autoLensCorrection)
                Toggle("Chroma noise reduction", isOn: $chromaNoiseReduction)
                Toggle("Preserve RAW color profile", isOn: $preserveRawColorProfile)
            }

            Section("History") {
                Stepper("Undo levels: \(undoLevels)", value: $undoLevels, in: 10...200, step: 10)
            }

            Section("Performance") {
                Toggle("Enable GPU acceleration", isOn: $enableGpuAcceleration)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Export Settings

struct ExportSettingsView: View {
    @AppStorage("defaultExportFormat") private var defaultExportFormat = "jpeg"
    @AppStorage("defaultJpegQuality") private var defaultJpegQuality = 0.9
    @AppStorage("includeMetadataByDefault") private var includeMetadataByDefault = true
    @AppStorage("stripLocationData") private var stripLocationData = false
    @AppStorage("writeXmpSidecar") private var writeXmpSidecar = false
    @AppStorage("addWatermark") private var addWatermark = false
    @AppStorage("watermarkText") private var watermarkText = ""

    var body: some View {
        Form {
            Section("Format") {
                Picker("Default format", selection: $defaultExportFormat) {
                    Text("JPEG").tag("jpeg")
                    Text("TIFF").tag("tiff")
                    Text("PNG").tag("png")
                    Text("HEIC").tag("heic")
                }

                if defaultExportFormat == "jpeg" || defaultExportFormat == "heic" {
                    HStack {
                        Text("Quality")
                        Slider(value: $defaultJpegQuality, in: 0.1...1.0)
                        Text("\(Int(defaultJpegQuality * 100))%")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                }
            }

            Section("Metadata") {
                Toggle("Include metadata by default", isOn: $includeMetadataByDefault)
                Toggle("Strip GPS/location data", isOn: $stripLocationData)
                Toggle("Write XMP sidecar file", isOn: $writeXmpSidecar)
            }

            Section("Watermark") {
                Toggle("Add watermark", isOn: $addWatermark)

                if addWatermark {
                    TextField("Watermark text", text: $watermarkText)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Performance Settings

struct PerformanceSettingsView: View {
    @AppStorage("thumbnailCacheSize") private var thumbnailCacheSize = 500
    @AppStorage("previewCacheSize") private var previewCacheSize = 100
    @AppStorage("maxConcurrentOperations") private var maxConcurrentOperations = 4
    @AppStorage("useProxyForPlayback") private var useProxyForPlayback = true
    @AppStorage("memoryUsageLimit") private var memoryUsageLimit = 4.0

    var body: some View {
        Form {
            Section("Cache") {
                Stepper("Thumbnail cache: \(thumbnailCacheSize) images", value: $thumbnailCacheSize, in: 100...2000, step: 100)
                Stepper("Preview cache: \(previewCacheSize) images", value: $previewCacheSize, in: 20...500, step: 20)

                Button("Clear Cache") {
                    clearCaches()
                }
            }

            Section("Processing") {
                Stepper("Max concurrent operations: \(maxConcurrentOperations)", value: $maxConcurrentOperations, in: 1...16)

                HStack {
                    Text("Memory limit")
                    Slider(value: $memoryUsageLimit, in: 1...16, step: 0.5)
                    Text("\(String(format: "%.1f", memoryUsageLimit)) GB")
                        .monospacedDigit()
                        .frame(width: 50)
                }
            }

            Section("Preview") {
                Toggle("Use proxy images for smooth playback", isOn: $useProxyForPlayback)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func clearCaches() {
        // TODO: Implement cache clearing
    }
}

// MARK: - Keyboard Shortcuts Settings

struct KeyboardSettingsView: View {
    var body: some View {
        Form {
            Section("Rating") {
                ShortcutRow(action: "Set Rating 1", shortcut: "1")
                ShortcutRow(action: "Set Rating 2", shortcut: "2")
                ShortcutRow(action: "Set Rating 3", shortcut: "3")
                ShortcutRow(action: "Set Rating 4", shortcut: "4")
                ShortcutRow(action: "Set Rating 5", shortcut: "5")
                ShortcutRow(action: "Clear Rating", shortcut: "0")
            }

            Section("Flags") {
                ShortcutRow(action: "Pick", shortcut: "P")
                ShortcutRow(action: "Reject", shortcut: "X")
                ShortcutRow(action: "Unflag", shortcut: "U")
            }

            Section("Navigation") {
                ShortcutRow(action: "Next Image", shortcut: "Right Arrow")
                ShortcutRow(action: "Previous Image", shortcut: "Left Arrow")
                ShortcutRow(action: "Toggle Grid/Detail", shortcut: "Return")
            }

            Section("Editing") {
                ShortcutRow(action: "Copy Adjustments", shortcut: "Cmd+Shift+C")
                ShortcutRow(action: "Paste Adjustments", shortcut: "Cmd+Shift+V")
                ShortcutRow(action: "Reset Adjustments", shortcut: "Cmd+Shift+R")
                ShortcutRow(action: "Show Before", shortcut: "\\")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct ShortcutRow: View {
    let action: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.secondary.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
}
