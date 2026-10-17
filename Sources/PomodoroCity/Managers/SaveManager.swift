import Foundation

public enum SaveError: LocalizedError {
    case fileNotFound
    case decodingFailed(String)
    case encodingFailed(String)
    case writeFailed(String)
    case corruptedSaveData
    case invalidBackupFormat

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Save file was not found."
        case .decodingFailed(let reason):
            return "Failed to decode save data: \(reason)"
        case .encodingFailed(let reason):
            return "Failed to encode save data: \(reason)"
        case .writeFailed(let reason):
            return "Failed to write save data to disk: \(reason)"
        case .corruptedSaveData:
            return "Save data is corrupted and cannot be safely loaded."
        case .invalidBackupFormat:
            return "The selected backup file is invalid or incompatible."
        }
    }
}

public class SaveManager {
    public static let shared = SaveManager()

    private let fileManager = FileManager.default

    public var customBaseDirectory: URL?

    public var appSupportDirectory: URL {
        if let custom = customBaseDirectory {
            if !fileManager.fileExists(atPath: custom.path) {
                try? fileManager.createDirectory(at: custom, withIntermediateDirectories: true, attributes: nil)
            }
            return custom
        }

        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        if let firstURL = urls.first {
            let dir = firstURL.appendingPathComponent("PomodoroCity", isDirectory: true)
            if (try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)) != nil,
               fileManager.isWritableFile(atPath: dir.path) || fileManager.fileExists(atPath: dir.path) {
                return dir
            }
        }

        // Fallback to Application Support in ~/Library or /tmp if restricted
        let fallback = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("PomodoroCity", isDirectory: true)
        try? fileManager.createDirectory(at: fallback, withIntermediateDirectories: true, attributes: nil)
        return fallback
    }

    public var saveFileURL: URL {
        return appSupportDirectory.appendingPathComponent("savegame.json")
    }

    private var backupFileURL: URL {
        return appSupportDirectory.appendingPathComponent("savegame.backup.json")
    }

    private init() {}

    /// Saves the game state safely using an atomic file write and updates the backup copy.
    public func save(state: GameState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(state) else {
            throw SaveError.encodingFailed("Could not serialize game state.")
        }

        let dir = appSupportDirectory
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }

        let targetURL = saveFileURL
        let tempURL = dir.appendingPathComponent("savegame.json.tmp")

        do {
            try data.write(to: tempURL, options: .atomic)

            if fileManager.fileExists(atPath: targetURL.path) {
                // Keep the previous save as a safety backup
                try? fileManager.removeItem(at: backupFileURL)
                try? fileManager.copyItem(at: targetURL, to: backupFileURL)
                try fileManager.removeItem(at: targetURL)
            }

            try fileManager.moveItem(at: tempURL, to: targetURL)
        } catch {
            throw SaveError.writeFailed(error.localizedDescription)
        }
    }

    /// Loads the active savegame. If corrupted, attempts fallback to the local backup.
    /// Never silently wipes data.
    public func load() throws -> GameState {
        let targetURL = saveFileURL

        guard fileManager.fileExists(atPath: targetURL.path) else {
            // First run: return fresh starter state
            let fresh = GameState()
            try save(state: fresh)
            return fresh
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try Data(contentsOf: targetURL)
            return try decoder.decode(GameState.self, from: data)
        } catch {
            // Main file failed to decode: try backup
            if fileManager.fileExists(atPath: backupFileURL.path),
               let backupData = try? Data(contentsOf: backupFileURL),
               let recovered = try? decoder.decode(GameState.self, from: backupData) {
                return recovered
            }
            throw SaveError.decodingFailed("Save data could not be parsed: \(error.localizedDescription)")
        }
    }

    /// Exports state to a user-chosen backup destination.
    public func exportBackup(state: GameState, to destinationURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(state)
        try data.write(to: destinationURL, options: .atomic)
    }

    /// Validates and imports a backup file.
    public func importBackup(from sourceURL: URL) throws -> GameState {
        let data = try Data(contentsOf: sourceURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let state = try? decoder.decode(GameState.self, from: data) else {
            throw SaveError.invalidBackupFormat
        }

        // Validate basic integrity
        guard state.version >= 1 else {
            throw SaveError.invalidBackupFormat
        }

        // Save imported state as primary save
        try save(state: state)
        return state
    }
}
