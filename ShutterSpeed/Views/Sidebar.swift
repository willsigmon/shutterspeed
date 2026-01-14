import SwiftUI

enum SidebarItem: Hashable {
    case allPhotos
    case recentImports
    case flagged
    case rejected
    case album(UUID)
}

struct Sidebar: View {
    @Binding var selectedTab: SidebarItem
    let albums: [Album]

    var body: some View {
        List(selection: $selectedTab) {
            Section("Library") {
                Label("All Photos", systemImage: "photo.on.rectangle")
                    .tag(SidebarItem.allPhotos)

                Label("Recent Imports", systemImage: "clock")
                    .tag(SidebarItem.recentImports)

                Label("Flagged", systemImage: "flag.fill")
                    .tag(SidebarItem.flagged)

                Label("Rejected", systemImage: "xmark.circle")
                    .tag(SidebarItem.rejected)
            }

            Section("Albums") {
                ForEach(regularAlbums) { album in
                    Label(album.name, systemImage: "rectangle.stack")
                        .tag(SidebarItem.album(album.id))
                }

                if regularAlbums.isEmpty {
                    Text("No albums")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }

            Section("Smart Albums") {
                ForEach(smartAlbums) { album in
                    Label(album.name, systemImage: "gearshape")
                        .tag(SidebarItem.album(album.id))
                }

                if smartAlbums.isEmpty {
                    Text("No smart albums")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
        }
        .listStyle(.sidebar)
        .contextMenu {
            Button("New Album...") {
                // TODO: Create album
            }

            Button("New Smart Album...") {
                // TODO: Create smart album
            }
        }
    }

    private var regularAlbums: [Album] {
        albums.filter { !$0.isSmart }
    }

    private var smartAlbums: [Album] {
        albums.filter { $0.isSmart }
    }
}

#Preview {
    Sidebar(
        selectedTab: .constant(.allPhotos),
        albums: [
            Album(id: UUID(), name: "Vacation 2024", isSmart: false),
            Album(id: UUID(), name: "Best Shots", isSmart: false),
            Album(id: UUID(), name: "5 Stars", isSmart: true, smartCriteria: SmartAlbumCriteria(rules: [
                SmartAlbumRule(field: .rating, comparison: .equals, value: "5")
            ])),
        ]
    )
    .frame(width: 220)
}
