import SwiftUI

/// Dialog for creating a new album
struct NewAlbumDialog: View {
    @Environment(\.dismiss) private var dismiss
    @State private var albumName = ""
    let onCreate: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("New Album")
                .font(.headline)

            TextField("Album Name", text: $albumName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Create") {
                    onCreate(albumName)
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(albumName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 300)
    }
}

/// Dialog for renaming an album
struct RenameAlbumDialog: View {
    @Environment(\.dismiss) private var dismiss
    @State private var albumName: String
    let originalName: String
    let onRename: (String) -> Void

    init(originalName: String, onRename: @escaping (String) -> Void) {
        self.originalName = originalName
        self._albumName = State(initialValue: originalName)
        self.onRename = onRename
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Rename Album")
                .font(.headline)

            TextField("Album Name", text: $albumName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Rename") {
                    onRename(albumName)
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(albumName.isEmpty || albumName == originalName)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 300)
    }
}

#Preview("New Album") {
    NewAlbumDialog { name in
        print("Created album: \(name)")
    }
}
