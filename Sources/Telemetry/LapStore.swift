import Foundation

/// A finished or ongoing session as written to disk: its laps, their traces and
/// the track. One JSON file per session.
struct StoredSession: Codable, Equatable {
    /// Sortable identifier, also the file name: milliseconds since 1970, zero padded.
    var id: String
    var gameID: String
    var savedAt: Date
    var session: SessionInfo
    var laps: [CompletedLap]
    var traces: [LapTrace]

    /// Best time of each sector across the session's laps.
    var bestSectorMS: [Int] {
        (0..<3).map { index in
            laps.map { [$0.sector1MS, $0.sector2MS, $0.sector3MS][index] }
                .filter { $0 > 0 }
                .min() ?? 0
        }
    }
}

/// Keeps the most recent sessions in the app's documents directory, so laps
/// survive closing the app. Older sessions are deleted.
final class LapStore {
    /// How many sessions stay on disk.
    static let keptSessions = 5

    let directory: URL
    private let queue = DispatchQueue(label: "LapStore", qos: .utility)

    init(directory: URL = LapStore.defaultDirectory) {
        self.directory = directory
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sessions", isDirectory: true)
    }

    /// A new session identifier; later sessions sort after earlier ones.
    static func newID(date: Date = Date()) -> String {
        String(format: "%015lld", Int64(date.timeIntervalSince1970 * 1000))
    }

    /// Writes the session in the background, then drops the oldest sessions.
    func save(_ session: StoredSession) {
        queue.async { [self] in try? write(session) }
    }

    /// Writes the session and prunes old ones on the calling thread.
    func write(_ session: StoredSession) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(session)
        try data.write(to: file(for: session.id), options: .atomic)
        for old in sessionFiles().dropFirst(Self.keptSessions) {
            try? FileManager.default.removeItem(at: old)
        }
    }

    /// The most recently started session that can still be read.
    func latest() -> StoredSession? {
        queue.sync {
            for url in sessionFiles() {
                if let data = try? Data(contentsOf: url),
                   let session = try? JSONDecoder().decode(StoredSession.self, from: data) {
                    return session
                }
            }
            return nil
        }
    }

    /// Session files, newest first.
    func sessionFiles() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private func file(for id: String) -> URL {
        directory.appendingPathComponent("\(id).json")
    }
}
