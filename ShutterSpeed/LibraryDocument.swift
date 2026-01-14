import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var photoLibrary: UTType {
        UTType(exportedAs: "com.wsig.shutterspeed.library", conformingTo: .package)
    }
}

@Observable
final class LibraryManager {
    var currentLibrary: PhotoLibrary?
    var showNewLibraryDialog = false
    var showOpenLibraryDialog = false
    var showImportDialog = false
    var recentLibraries: [URL] = []

    init() {
        loadRecentLibraries()
    }

    func createLibrary(at url: URL, name: String) async throws {
        let library = try await PhotoLibrary.create(at: url, name: name)
        await MainActor.run {
            self.currentLibrary = library
            self.addToRecentLibraries(url)
        }
    }

    func openLibrary(at url: URL) async {
        do {
            let library = try await PhotoLibrary.open(at: url)
            await MainActor.run {
                self.currentLibrary = library
                self.addToRecentLibraries(url)
            }
        } catch {
            print("Failed to open library: \(error)")
        }
    }

    func closeLibrary() {
        currentLibrary?.close()
        currentLibrary = nil
    }

    private func addToRecentLibraries(_ url: URL) {
        recentLibraries.removeAll { $0 == url }
        recentLibraries.insert(url, at: 0)
        if recentLibraries.count > 10 {
            recentLibraries = Array(recentLibraries.prefix(10))
        }
        saveRecentLibraries()
    }

    private func loadRecentLibraries() {
        if let data = UserDefaults.standard.data(forKey: "recentLibraries"),
           let urls = try? JSONDecoder().decode([URL].self, from: data) {
            recentLibraries = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        }
    }

    private func saveRecentLibraries() {
        if let data = try? JSONEncoder().encode(recentLibraries) {
            UserDefaults.standard.set(data, forKey: "recentLibraries")
        }
    }
}
