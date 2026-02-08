import Foundation

final class ActiveHikeCheckpointStore: ActiveHikeStatePersistenceService {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func save(_ checkpoint: ActiveHikeCheckpoint) {
        do {
            try ensureDirectory()
            let data = try encoder.encode(checkpoint)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return
        }
    }

    func load() -> ActiveHikeCheckpoint? {
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(ActiveHikeCheckpoint.self, from: data)
        } catch {
            return nil
        }
    }

    func clear() {
        try? fileManager.removeItem(at: fileURL)
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private var directoryURL: URL {
        let fallback = URL(fileURLWithPath: NSTemporaryDirectory())
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fallback
        return base.appendingPathComponent("TrailMind", isDirectory: true)
    }

    private var fileURL: URL {
        directoryURL.appendingPathComponent("active-hike-checkpoint.json")
    }
}
