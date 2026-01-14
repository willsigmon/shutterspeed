import SwiftUI
import Carbon.HIToolbox

/// Centralized keyboard shortcut handling
enum KeyboardShortcuts {
    // MARK: - Rating (1-5, 0 for none)
    static let rating0 = KeyboardShortcut("0")
    static let rating1 = KeyboardShortcut("1")
    static let rating2 = KeyboardShortcut("2")
    static let rating3 = KeyboardShortcut("3")
    static let rating4 = KeyboardShortcut("4")
    static let rating5 = KeyboardShortcut("5")

    // MARK: - Flags
    static let flagPick = KeyboardShortcut("p")
    static let flagReject = KeyboardShortcut("x")
    static let flagRemove = KeyboardShortcut("u")

    // MARK: - Color Labels
    static let labelRed = KeyboardShortcut("6")
    static let labelOrange = KeyboardShortcut("7")
    static let labelYellow = KeyboardShortcut("8")
    static let labelGreen = KeyboardShortcut("9")
    static let labelBlue = KeyboardShortcut("0", modifiers: .option)
    static let labelPurple = KeyboardShortcut("-", modifiers: .option)
    static let labelNone = KeyboardShortcut("=", modifiers: .option)

    // MARK: - Navigation
    static let nextImage = KeyboardShortcut(.rightArrow)
    static let previousImage = KeyboardShortcut(.leftArrow)
    static let firstImage = KeyboardShortcut(.home)
    static let lastImage = KeyboardShortcut(.end)

    // MARK: - View
    static let toggleGrid = KeyboardShortcut("g")
    static let toggleDetail = KeyboardShortcut(.return)
    static let toggleLoupe = KeyboardShortcut("l")
    static let toggleBeforeAfter = KeyboardShortcut("\\")
    static let zoomIn = KeyboardShortcut("=", modifiers: .command)
    static let zoomOut = KeyboardShortcut("-", modifiers: .command)
    static let zoomFit = KeyboardShortcut("0", modifiers: .command)
    static let zoom100 = KeyboardShortcut("1", modifiers: .command)

    // MARK: - Edit
    static let copyAdjustments = KeyboardShortcut("c", modifiers: [.command, .shift])
    static let pasteAdjustments = KeyboardShortcut("v", modifiers: [.command, .shift])
    static let resetAdjustments = KeyboardShortcut("r", modifiers: [.command, .shift])
    static let autoEnhance = KeyboardShortcut("e", modifiers: [.command, .shift])

    // MARK: - Organization
    static let addToAlbum = KeyboardShortcut("b", modifiers: .command)
    static let addKeyword = KeyboardShortcut("k", modifiers: .command)
    static let showInfo = KeyboardShortcut("i", modifiers: .command)

    // MARK: - File
    static let import_ = KeyboardShortcut("i", modifiers: [.command, .shift])
    static let export = KeyboardShortcut("e", modifiers: .command)
    static let showInFinder = KeyboardShortcut("r", modifiers: .command)
    static let delete = KeyboardShortcut(.delete, modifiers: .command)

    // MARK: - Selection
    static let selectAll = KeyboardShortcut("a", modifiers: .command)
    static let deselectAll = KeyboardShortcut("d", modifiers: .command)
    static let invertSelection = KeyboardShortcut("i", modifiers: [.command, .option])
}

// MARK: - Shortcut Handler

@Observable
final class ShortcutHandler {
    var selectedImages: Set<UUID> = []
    var library: PhotoLibrary?

    // Clipboard for lift/stamp
    private var copiedAdjustments: [Adjustment]?

    // MARK: - Rating

    func setRating(_ rating: Int) {
        guard let library else { return }
        for imageID in selectedImages {
            try? library.database.updateImageRating(imageID, rating: rating)
            if let index = library.images.firstIndex(where: { $0.id == imageID }) {
                library.images[index].rating = rating
            }
        }
    }

    // MARK: - Flags

    func setFlag(_ flag: Flag) {
        guard let library else { return }
        for imageID in selectedImages {
            try? library.database.updateImageFlag(imageID, flag: flag)
            if let index = library.images.firstIndex(where: { $0.id == imageID }) {
                library.images[index].flag = flag
            }
        }
    }

    // MARK: - Color Labels

    func setColorLabel(_ label: ColorLabel) {
        guard let library else { return }
        for imageID in selectedImages {
            try? library.database.updateImageColorLabel(imageID, colorLabel: label)
            if let index = library.images.firstIndex(where: { $0.id == imageID }) {
                library.images[index].colorLabel = label
            }
        }
    }

    // MARK: - Lift/Stamp (Copy/Paste Adjustments)

    func copyAdjustments(from editState: EditState?) {
        copiedAdjustments = editState?.adjustments
    }

    func pasteAdjustments() -> [Adjustment]? {
        return copiedAdjustments
    }

    // MARK: - Navigation

    func nextImage(in images: [PhotoImage]) -> UUID? {
        guard let current = selectedImages.first,
              let currentIndex = images.firstIndex(where: { $0.id == current }),
              currentIndex < images.count - 1 else {
            return images.first?.id
        }
        return images[currentIndex + 1].id
    }

    func previousImage(in images: [PhotoImage]) -> UUID? {
        guard let current = selectedImages.first,
              let currentIndex = images.firstIndex(where: { $0.id == current }),
              currentIndex > 0 else {
            return images.last?.id
        }
        return images[currentIndex - 1].id
    }
}

// MARK: - View Extension for Keyboard Handling

struct KeyboardShortcutModifier: ViewModifier {
    let handler: ShortcutHandler
    let images: [PhotoImage]
    @Binding var selectedIDs: Set<UUID>

    func body(content: Content) -> some View {
        content
            // Rating shortcuts
            .onKeyPress("0") { handler.setRating(0); return .handled }
            .onKeyPress("1") { handler.setRating(1); return .handled }
            .onKeyPress("2") { handler.setRating(2); return .handled }
            .onKeyPress("3") { handler.setRating(3); return .handled }
            .onKeyPress("4") { handler.setRating(4); return .handled }
            .onKeyPress("5") { handler.setRating(5); return .handled }

            // Flag shortcuts
            .onKeyPress("p") { handler.setFlag(.pick); return .handled }
            .onKeyPress("x") { handler.setFlag(.reject); return .handled }
            .onKeyPress("u") { handler.setFlag(.none); return .handled }

            // Navigation
            .onKeyPress(.rightArrow) {
                if let next = handler.nextImage(in: images) {
                    selectedIDs = [next]
                }
                return .handled
            }
            .onKeyPress(.leftArrow) {
                if let prev = handler.previousImage(in: images) {
                    selectedIDs = [prev]
                }
                return .handled
            }
    }
}

extension View {
    func keyboardShortcuts(
        handler: ShortcutHandler,
        images: [PhotoImage],
        selectedIDs: Binding<Set<UUID>>
    ) -> some View {
        modifier(KeyboardShortcutModifier(
            handler: handler,
            images: images,
            selectedIDs: selectedIDs
        ))
    }
}
