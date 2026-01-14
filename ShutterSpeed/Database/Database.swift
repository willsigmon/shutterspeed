import Foundation
import SQLite3

final class Database {
    private var db: OpaquePointer?
    private let url: URL
    private let queue = DispatchQueue(label: "com.wsig.shutterspeed.database", qos: .userInitiated)

    init(url: URL) throws {
        self.url = url

        var db: OpaquePointer?
        let result = sqlite3_open_v2(
            url.path,
            &db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )

        guard result == SQLITE_OK else {
            throw DatabaseError.failedToOpen(result)
        }

        self.db = db

        // Enable WAL mode for better performance
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA synchronous = NORMAL")
        try execute("PRAGMA foreign_keys = ON")
    }

    deinit {
        close()
    }

    func close() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    // MARK: - Schema

    func initialize() throws {
        try execute(Schema.createTables)
        try execute(Schema.createIndexes)
    }

    // MARK: - Library

    func insertLibrary(id: UUID, name: String) throws {
        let sql = """
            INSERT INTO libraries (id, name, created_at, schema_version)
            VALUES (?, ?, ?, 1)
        """
        try execute(sql, params: [id.uuidString, name, ISO8601DateFormatter().string(from: Date())])
    }

    func getLibraryName() throws -> String? {
        let sql = "SELECT name FROM libraries LIMIT 1"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }

        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return String(cString: sqlite3_column_text(stmt, 0))
        }

        return nil
    }

    // MARK: - Images

    func insertImage(_ image: PhotoImage) throws {
        let sql = """
            INSERT INTO images (
                id, library_id, file_path, file_name, file_size, file_hash,
                width, height, capture_date, import_date,
                camera_make, camera_model, lens_model,
                iso, aperture, shutter_speed, focal_length,
                gps_latitude, gps_longitude,
                rating, flag, color_label
            ) VALUES (?, (SELECT id FROM libraries LIMIT 1), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        let dateFormatter = ISO8601DateFormatter()

        try execute(sql, params: [
            image.id.uuidString,
            image.filePath.path,
            image.fileName,
            image.fileSize as Any,
            image.fileHash as Any,
            image.width as Any,
            image.height as Any,
            image.captureDate.map { dateFormatter.string(from: $0) } as Any,
            dateFormatter.string(from: image.importDate),
            image.metadata.cameraMake as Any,
            image.metadata.cameraModel as Any,
            image.metadata.lensModel as Any,
            image.metadata.iso as Any,
            image.metadata.aperture as Any,
            image.metadata.shutterSpeed as Any,
            image.metadata.focalLength as Any,
            image.metadata.gpsLatitude as Any,
            image.metadata.gpsLongitude as Any,
            image.rating,
            image.flag.rawValue,
            image.colorLabel.rawValue
        ])
    }

    func fetchAllImages() throws -> [PhotoImage] {
        let sql = """
            SELECT id, file_path, file_name, file_size, file_hash,
                   width, height, capture_date, import_date,
                   camera_make, camera_model, lens_model,
                   iso, aperture, shutter_speed, focal_length,
                   gps_latitude, gps_longitude,
                   rating, flag, color_label
            FROM images
            ORDER BY capture_date DESC, import_date DESC
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }

        defer { sqlite3_finalize(stmt) }

        var images: [PhotoImage] = []
        let dateFormatter = ISO8601DateFormatter()

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0)))!
            let filePath = URL(fileURLWithPath: String(cString: sqlite3_column_text(stmt, 1)))
            let fileName = String(cString: sqlite3_column_text(stmt, 2))

            var metadata = ImageMetadata()
            metadata.width = columnInt(stmt, 5)
            metadata.height = columnInt(stmt, 6)
            metadata.cameraMake = columnString(stmt, 9)
            metadata.cameraModel = columnString(stmt, 10)
            metadata.lensModel = columnString(stmt, 11)
            metadata.iso = columnInt(stmt, 12)
            metadata.aperture = columnDouble(stmt, 13)
            metadata.shutterSpeed = columnString(stmt, 14)
            metadata.focalLength = columnDouble(stmt, 15)
            metadata.gpsLatitude = columnDouble(stmt, 16)
            metadata.gpsLongitude = columnDouble(stmt, 17)

            var image = PhotoImage(id: id, filePath: filePath, fileName: fileName, metadata: metadata)
            image.fileSize = columnInt64(stmt, 3)
            image.fileHash = columnString(stmt, 4)

            if let captureDateStr = columnString(stmt, 7) {
                image.captureDate = dateFormatter.date(from: captureDateStr)
            }
            if let importDateStr = columnString(stmt, 8) {
                image.importDate = dateFormatter.date(from: importDateStr) ?? Date()
            }

            image.rating = columnInt(stmt, 18) ?? 0
            image.flag = Flag(rawValue: columnInt(stmt, 19) ?? 0) ?? .none
            image.colorLabel = ColorLabel(rawValue: columnInt(stmt, 20) ?? 0) ?? .none

            images.append(image)
        }

        return images
    }

    func updateImageRating(_ imageID: UUID, rating: Int) throws {
        try execute("UPDATE images SET rating = ? WHERE id = ?", params: [rating, imageID.uuidString])
    }

    func updateImageFlag(_ imageID: UUID, flag: Flag) throws {
        try execute("UPDATE images SET flag = ? WHERE id = ?", params: [flag.rawValue, imageID.uuidString])
    }

    func updateImageColorLabel(_ imageID: UUID, colorLabel: ColorLabel) throws {
        try execute("UPDATE images SET color_label = ? WHERE id = ?", params: [colorLabel.rawValue, imageID.uuidString])
    }

    // MARK: - Keywords

    func addKeyword(_ keyword: String, to imageID: UUID) throws {
        // Insert keyword if not exists
        try execute("INSERT OR IGNORE INTO keywords (id, word) VALUES (?, ?)", params: [UUID().uuidString, keyword])

        // Link to image
        let sql = """
            INSERT OR IGNORE INTO image_keywords (image_id, keyword_id)
            SELECT ?, id FROM keywords WHERE word = ?
        """
        try execute(sql, params: [imageID.uuidString, keyword])
    }

    func removeKeyword(_ keyword: String, from imageID: UUID) throws {
        let sql = """
            DELETE FROM image_keywords
            WHERE image_id = ? AND keyword_id = (SELECT id FROM keywords WHERE word = ?)
        """
        try execute(sql, params: [imageID.uuidString, keyword])
    }

    func fetchKeywords(for imageID: UUID) throws -> [String] {
        let sql = """
            SELECT k.word FROM keywords k
            JOIN image_keywords ik ON k.id = ik.keyword_id
            WHERE ik.image_id = ?
            ORDER BY k.word
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }

        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, imageID.uuidString, -1, SQLITE_TRANSIENT)

        var keywords: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            keywords.append(String(cString: sqlite3_column_text(stmt, 0)))
        }

        return keywords
    }

    // MARK: - Albums

    func insertAlbum(_ album: Album) throws {
        let sql = """
            INSERT INTO albums (id, name, parent_id, is_smart, smart_criteria, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
        """

        var criteriaJSON: String?
        if let criteria = album.smartCriteria {
            criteriaJSON = String(data: try JSONEncoder().encode(criteria), encoding: .utf8)
        }

        try execute(sql, params: [
            album.id.uuidString,
            album.name,
            album.parentID?.uuidString as Any,
            album.isSmart ? 1 : 0,
            criteriaJSON as Any,
            ISO8601DateFormatter().string(from: album.createdAt)
        ])
    }

    func fetchAllAlbums() throws -> [Album] {
        let sql = "SELECT id, name, parent_id, is_smart, smart_criteria, created_at FROM albums ORDER BY name"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }

        defer { sqlite3_finalize(stmt) }

        var albums: [Album] = []
        let dateFormatter = ISO8601DateFormatter()

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0)))!
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let parentID = columnString(stmt, 2).flatMap { UUID(uuidString: $0) }
            let isSmart = sqlite3_column_int(stmt, 3) == 1

            var criteria: SmartAlbumCriteria?
            if let criteriaStr = columnString(stmt, 4),
               let data = criteriaStr.data(using: .utf8) {
                criteria = try? JSONDecoder().decode(SmartAlbumCriteria.self, from: data)
            }

            let createdAt = columnString(stmt, 5).flatMap { dateFormatter.date(from: $0) } ?? Date()

            albums.append(Album(
                id: id,
                name: name,
                parentID: parentID,
                isSmart: isSmart,
                smartCriteria: criteria,
                createdAt: createdAt
            ))
        }

        return albums
    }

    // MARK: - Edits

    func saveEdit(_ edit: EditState) throws {
        let adjustmentsJSON = try JSONEncoder().encode(edit.adjustments)

        let sql = """
            INSERT INTO edits (id, image_id, version, adjustments, created_at)
            VALUES (?, ?, ?, ?, ?)
        """

        try execute(sql, params: [
            edit.id.uuidString,
            edit.imageID.uuidString,
            edit.version,
            String(data: adjustmentsJSON, encoding: .utf8)!,
            ISO8601DateFormatter().string(from: edit.createdAt)
        ])
    }

    func fetchLatestEdit(for imageID: UUID) throws -> EditState? {
        let sql = """
            SELECT id, image_id, version, adjustments, created_at
            FROM edits WHERE image_id = ? ORDER BY version DESC LIMIT 1
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }

        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, imageID.uuidString, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0)))!
        let imgID = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 1)))!
        let version = Int(sqlite3_column_int(stmt, 2))
        let adjustmentsStr = String(cString: sqlite3_column_text(stmt, 3))
        let createdAtStr = String(cString: sqlite3_column_text(stmt, 4))

        let adjustments = try JSONDecoder().decode([Adjustment].self, from: adjustmentsStr.data(using: .utf8)!)
        let createdAt = ISO8601DateFormatter().date(from: createdAtStr) ?? Date()

        var edit = EditState(imageID: imgID, version: version)
        edit.adjustments = adjustments

        return edit
    }

    // MARK: - Helpers

    private func execute(_ sql: String, params: [Any] = []) throws {
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.prepareFailed
        }

        defer { sqlite3_finalize(stmt) }

        for (index, param) in params.enumerated() {
            let idx = Int32(index + 1)
            switch param {
            case let value as String:
                sqlite3_bind_text(stmt, idx, value, -1, SQLITE_TRANSIENT)
            case let value as Int:
                sqlite3_bind_int64(stmt, idx, Int64(value))
            case let value as Int64:
                sqlite3_bind_int64(stmt, idx, value)
            case let value as Double:
                sqlite3_bind_double(stmt, idx, value)
            case is NSNull:
                sqlite3_bind_null(stmt, idx)
            case Optional<Any>.none:
                sqlite3_bind_null(stmt, idx)
            default:
                if let optional = param as? OptionalProtocol, optional.isNil {
                    sqlite3_bind_null(stmt, idx)
                } else {
                    sqlite3_bind_text(stmt, idx, "\(param)", -1, SQLITE_TRANSIENT)
                }
            }
        }

        let result = sqlite3_step(stmt)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            let error = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.executionFailed(error)
        }
    }

    private func columnString(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let text = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: text)
    }

    private func columnInt(_ stmt: OpaquePointer?, _ index: Int32) -> Int? {
        sqlite3_column_type(stmt, index) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, index))
    }

    private func columnInt64(_ stmt: OpaquePointer?, _ index: Int32) -> Int64? {
        sqlite3_column_type(stmt, index) == SQLITE_NULL ? nil : sqlite3_column_int64(stmt, index)
    }

    private func columnDouble(_ stmt: OpaquePointer?, _ index: Int32) -> Double? {
        sqlite3_column_type(stmt, index) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, index)
    }
}

// MARK: - Schema

private enum Schema {
    static let createTables = """
        CREATE TABLE IF NOT EXISTS libraries (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL,
            schema_version INTEGER DEFAULT 1
        );

        CREATE TABLE IF NOT EXISTS images (
            id TEXT PRIMARY KEY,
            library_id TEXT NOT NULL,
            file_path TEXT NOT NULL,
            file_name TEXT NOT NULL,
            file_size INTEGER,
            file_hash TEXT,
            width INTEGER,
            height INTEGER,
            capture_date TEXT,
            import_date TEXT NOT NULL,
            camera_make TEXT,
            camera_model TEXT,
            lens_model TEXT,
            iso INTEGER,
            aperture REAL,
            shutter_speed TEXT,
            focal_length REAL,
            gps_latitude REAL,
            gps_longitude REAL,
            rating INTEGER DEFAULT 0,
            flag INTEGER DEFAULT 0,
            color_label INTEGER DEFAULT 0,
            FOREIGN KEY (library_id) REFERENCES libraries(id)
        );

        CREATE TABLE IF NOT EXISTS thumbnails (
            image_id TEXT PRIMARY KEY,
            thumb_256 BLOB,
            thumb_1024 BLOB,
            FOREIGN KEY (image_id) REFERENCES images(id)
        );

        CREATE TABLE IF NOT EXISTS edits (
            id TEXT PRIMARY KEY,
            image_id TEXT NOT NULL,
            version INTEGER DEFAULT 1,
            adjustments TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (image_id) REFERENCES images(id)
        );

        CREATE TABLE IF NOT EXISTS keywords (
            id TEXT PRIMARY KEY,
            word TEXT NOT NULL UNIQUE
        );

        CREATE TABLE IF NOT EXISTS image_keywords (
            image_id TEXT NOT NULL,
            keyword_id TEXT NOT NULL,
            PRIMARY KEY (image_id, keyword_id),
            FOREIGN KEY (image_id) REFERENCES images(id),
            FOREIGN KEY (keyword_id) REFERENCES keywords(id)
        );

        CREATE TABLE IF NOT EXISTS albums (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parent_id TEXT,
            is_smart INTEGER DEFAULT 0,
            smart_criteria TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (parent_id) REFERENCES albums(id)
        );

        CREATE TABLE IF NOT EXISTS album_images (
            album_id TEXT NOT NULL,
            image_id TEXT NOT NULL,
            sort_order INTEGER DEFAULT 0,
            PRIMARY KEY (album_id, image_id),
            FOREIGN KEY (album_id) REFERENCES albums(id),
            FOREIGN KEY (image_id) REFERENCES images(id)
        );
    """

    static let createIndexes = """
        CREATE INDEX IF NOT EXISTS idx_images_capture_date ON images(capture_date);
        CREATE INDEX IF NOT EXISTS idx_images_rating ON images(rating);
        CREATE INDEX IF NOT EXISTS idx_images_flag ON images(flag);
        CREATE INDEX IF NOT EXISTS idx_images_import_date ON images(import_date);
        CREATE INDEX IF NOT EXISTS idx_keywords_word ON keywords(word);
    """
}

// MARK: - Errors

enum DatabaseError: Error {
    case failedToOpen(Int32)
    case prepareFailed
    case executionFailed(String)
}

// MARK: - Optional Protocol Helper

private protocol OptionalProtocol {
    var isNil: Bool { get }
}

extension Optional: OptionalProtocol {
    var isNil: Bool { self == nil }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
