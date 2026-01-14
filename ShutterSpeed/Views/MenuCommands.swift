import SwiftUI

/// Application menu commands
struct AppMenuCommands: Commands {
    @FocusedBinding(\.selectedImages) var selectedImages
    @FocusedBinding(\.library) var library
    @FocusedValue(\.importAction) var importAction
    @FocusedValue(\.exportAction) var exportAction

    var body: some Commands {
        // File Menu additions
        CommandGroup(after: .newItem) {
            Button("Import Photos...") {
                importAction?()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Button("Export Selected...") {
                exportAction?()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(selectedImages?.isEmpty ?? true)

            Divider()
        }

        // Edit Menu additions
        CommandGroup(after: .pasteboard) {
            Divider()

            Button("Copy Adjustments") {
                // Copy adjustments from current image
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(selectedImages?.count != 1)

            Button("Paste Adjustments") {
                // Paste adjustments to selected images
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            .disabled(selectedImages?.isEmpty ?? true)

            Divider()

            Button("Select All") {
                // Select all images
            }
            .keyboardShortcut("a", modifiers: .command)

            Button("Deselect All") {
                // Deselect all images
            }
            .keyboardShortcut("d", modifiers: .command)
        }

        // Photo Menu
        CommandMenu("Photo") {
            // Rating submenu
            Menu("Set Rating") {
                ForEach(0...5, id: \.self) { rating in
                    Button(rating == 0 ? "No Rating" : String(repeating: "\u{2605}", count: rating)) {
                        setRating(rating)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(rating)")), modifiers: [])
                }
            }

            Divider()

            // Flag submenu
            Menu("Set Flag") {
                Button("Pick") {
                    setFlag(.pick)
                }
                .keyboardShortcut("p", modifiers: [])

                Button("Reject") {
                    setFlag(.reject)
                }
                .keyboardShortcut("x", modifiers: [])

                Button("Unflagged") {
                    setFlag(.unflagged)
                }
                .keyboardShortcut("u", modifiers: [])
            }

            Divider()

            // Color labels
            Menu("Set Color Label") {
                Button("Red") { setColorLabel(.red) }
                    .keyboardShortcut("6", modifiers: [])
                Button("Yellow") { setColorLabel(.yellow) }
                    .keyboardShortcut("7", modifiers: [])
                Button("Green") { setColorLabel(.green) }
                    .keyboardShortcut("8", modifiers: [])
                Button("Blue") { setColorLabel(.blue) }
                    .keyboardShortcut("9", modifiers: [])
                Button("Purple") { setColorLabel(.purple) }
                Divider()
                Button("None") { setColorLabel(.none) }
            }

            Divider()

            Button("Rotate Left") {
                rotateImages(clockwise: false)
            }
            .keyboardShortcut("[", modifiers: .command)

            Button("Rotate Right") {
                rotateImages(clockwise: true)
            }
            .keyboardShortcut("]", modifiers: .command)

            Divider()

            Button("Move to Trash") {
                moveToTrash()
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(selectedImages?.isEmpty ?? true)
        }

        // Develop Menu
        CommandMenu("Develop") {
            Button("Auto Tone") {
                applyAutoTone()
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])

            Button("Auto White Balance") {
                applyAutoWhiteBalance()
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])

            Divider()

            Button("Reset Adjustments") {
                resetAdjustments()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Reset to Import") {
                resetToImport()
            }

            Divider()

            Button("Enable Lens Corrections") {
                enableLensCorrections()
            }

            Button("Enable Chromatic Aberration Removal") {
                enableChromaticAberrationRemoval()
            }

            Divider()

            Button("Create Virtual Copy") {
                createVirtualCopy()
            }
            .keyboardShortcut("'", modifiers: .command)

            Divider()

            Button("Sync Settings...") {
                syncSettings()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(selectedImages?.isEmpty ?? true)
        }

        // View Menu additions
        CommandGroup(after: .toolbar) {
            Divider()

            Button("Grid View") {
                setViewMode(.grid)
            }
            .keyboardShortcut("g", modifiers: .command)

            Button("Detail View") {
                setViewMode(.detail)
            }
            .keyboardShortcut("d", modifiers: [.command, .option])

            Button("Compare View") {
                setViewMode(.compare)
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button("Show Before/After") {
                toggleBeforeAfter()
            }
            .keyboardShortcut("\\", modifiers: [])

            Divider()

            Button("Zoom In") {
                zoomIn()
            }
            .keyboardShortcut("+", modifiers: .command)

            Button("Zoom Out") {
                zoomOut()
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("Fit to Window") {
                zoomToFit()
            }
            .keyboardShortcut("0", modifiers: .command)

            Button("Actual Size") {
                zoomToActualSize()
            }
            .keyboardShortcut("1", modifiers: [.command, .option])
        }

        // Window Menu additions
        CommandGroup(after: .windowArrangement) {
            Divider()

            Button("Show Inspector") {
                toggleInspector()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])

            Button("Show Filters") {
                toggleFilters()
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
        }

        // Help Menu additions
        CommandGroup(replacing: .help) {
            Button("ShutterSpeed Help") {
                openHelp()
            }
            .keyboardShortcut("?", modifiers: .command)

            Divider()

            Button("Keyboard Shortcuts") {
                showKeyboardShortcuts()
            }

            Button("What's New") {
                showWhatsNew()
            }

            Divider()

            Link("Visit Website", destination: URL(string: "https://shutterspeed.app")!)

            Link("Send Feedback", destination: URL(string: "mailto:feedback@shutterspeed.app")!)
        }
    }

    // MARK: - Actions

    private func setRating(_ rating: Int) {
        guard let images = selectedImages else { return }
        for image in images {
            image.rating = rating
        }
    }

    private func setFlag(_ flag: PhotoFlag) {
        guard let images = selectedImages else { return }
        for image in images {
            image.flag = flag
        }
    }

    private func setColorLabel(_ label: ColorLabel) {
        guard let images = selectedImages else { return }
        for image in images {
            image.colorLabel = label
        }
    }

    private func rotateImages(clockwise: Bool) {
        guard let images = selectedImages else { return }
        let angle = clockwise ? 90.0 : -90.0
        for image in images {
            image.editState.rotation += angle
        }
    }

    private func moveToTrash() {
        // Move selected images to trash
    }

    private func applyAutoTone() {
        // Apply auto tone to selected images
    }

    private func applyAutoWhiteBalance() {
        // Apply auto white balance
    }

    private func resetAdjustments() {
        guard let images = selectedImages else { return }
        for image in images {
            image.editState = EditState()
        }
    }

    private func resetToImport() {
        // Reset to original import state
    }

    private func enableLensCorrections() {
        // Enable lens profile corrections
    }

    private func enableChromaticAberrationRemoval() {
        // Enable CA removal
    }

    private func createVirtualCopy() {
        // Create virtual copy of selected image
    }

    private func syncSettings() {
        // Open sync settings dialog
    }

    private func setViewMode(_ mode: ViewMode) {
        // Set view mode
    }

    private func toggleBeforeAfter() {
        // Toggle before/after view
    }

    private func zoomIn() {
        // Zoom in
    }

    private func zoomOut() {
        // Zoom out
    }

    private func zoomToFit() {
        // Fit to window
    }

    private func zoomToActualSize() {
        // Zoom to 100%
    }

    private func toggleInspector() {
        // Toggle inspector panel
    }

    private func toggleFilters() {
        // Toggle filter bar
    }

    private func openHelp() {
        if let url = URL(string: "https://shutterspeed.app/help") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showKeyboardShortcuts() {
        // Show keyboard shortcuts window
    }

    private func showWhatsNew() {
        // Show what's new window
    }
}

// MARK: - Focused Values

struct SelectedImagesFocusedValueKey: FocusedValueKey {
    typealias Value = Binding<[PhotoImage]>
}

struct LibraryFocusedValueKey: FocusedValueKey {
    typealias Value = Binding<PhotoLibrary?>
}

struct ImportActionFocusedValueKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ExportActionFocusedValueKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var selectedImages: Binding<[PhotoImage]>? {
        get { self[SelectedImagesFocusedValueKey.self] }
        set { self[SelectedImagesFocusedValueKey.self] = newValue }
    }

    var library: Binding<PhotoLibrary?>? {
        get { self[LibraryFocusedValueKey.self] }
        set { self[LibraryFocusedValueKey.self] = newValue }
    }

    var importAction: (() -> Void)? {
        get { self[ImportActionFocusedValueKey.self] }
        set { self[ImportActionFocusedValueKey.self] = newValue }
    }

    var exportAction: (() -> Void)? {
        get { self[ExportActionFocusedValueKey.self] }
        set { self[ExportActionFocusedValueKey.self] = newValue }
    }
}

// MARK: - Photo Flag Enum (if not already defined elsewhere)

enum PhotoFlag: String, Codable, CaseIterable {
    case unflagged
    case pick
    case reject
}

// MARK: - Color Label Enum

enum ColorLabel: String, Codable, CaseIterable {
    case none
    case red
    case yellow
    case green
    case blue
    case purple

    var color: Color {
        switch self {
        case .none: return .clear
        case .red: return .red
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        }
    }
}

// MARK: - Quick Actions Menu

struct QuickActionsMenu: View {
    let image: PhotoImage
    let onEdit: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button("Edit in Detail View", action: onEdit)

            Divider()

            Menu("Set Rating") {
                ForEach(0...5, id: \.self) { rating in
                    Button(rating == 0 ? "No Rating" : String(repeating: "\u{2605}", count: rating)) {
                        image.rating = rating
                    }
                }
            }

            Menu("Set Flag") {
                Button("Pick") { image.flag = .pick }
                Button("Reject") { image.flag = .reject }
                Button("Unflagged") { image.flag = .unflagged }
            }

            Menu("Set Color Label") {
                ForEach(ColorLabel.allCases, id: \.self) { label in
                    Button {
                        image.colorLabel = label
                    } label: {
                        HStack {
                            if label != .none {
                                Circle()
                                    .fill(label.color)
                                    .frame(width: 8, height: 8)
                            }
                            Text(label.rawValue.capitalized)
                        }
                    }
                }
            }

            Divider()

            Button("Export...", action: onExport)

            Divider()

            Button("Move to Trash", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
