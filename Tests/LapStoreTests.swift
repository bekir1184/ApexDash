import XCTest
@testable import ApexDash

/// Saved sessions: they round-trip through JSON, only the newest few are kept,
/// and a fresh client shows the last one.
@MainActor
final class LapStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LapStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func testSessionRoundTrips() throws {
        let store = LapStore(directory: directory)
        let session = makeSession(id: LapStore.newID())
        try store.write(session)

        let loaded = try XCTUnwrap(store.latest())
        XCTAssertEqual(loaded, session)
        XCTAssertEqual(loaded.traces[0].samples.count, 40)
        XCTAssertEqual(loaded.bestSectorMS, [30_000, 30_500, 31_000])
    }

    func testKeepsOnlyNewestSessions() throws {
        let store = LapStore(directory: directory)
        let start = Date()
        for index in 0..<(LapStore.keptSessions + 3) {
            try store.write(makeSession(id: LapStore.newID(date: start.addingTimeInterval(Double(index) * 60))))
        }
        XCTAssertEqual(store.sessionFiles().count, LapStore.keptSessions)
        XCTAssertEqual(store.latest()?.id, LapStore.newID(date: start.addingTimeInterval(Double(LapStore.keptSessions + 2) * 60)))
    }

    func testRewritingASessionReplacesIt() throws {
        let store = LapStore(directory: directory)
        var session = makeSession(id: LapStore.newID())
        try store.write(session)
        session.laps.append(session.laps[0])
        try store.write(session)
        XCTAssertEqual(store.sessionFiles().count, 1)
        XCTAssertEqual(store.latest()?.laps.count, 3)
    }

    func testClientShowsSavedSessionAtLaunch() throws {
        let store = LapStore(directory: directory)
        let session = makeSession(id: LapStore.newID())
        try store.write(session)

        let client = TelemetryClient(game: F1Game(), store: store)
        XCTAssertTrue(client.showsSavedSession)
        XCTAssertEqual(client.shownLaps, session.laps)
        XCTAssertEqual(client.shownTraces, session.traces)
        XCTAssertEqual(client.shownSession.trackID, 10)
    }

    func testDemoLapsReplaceSavedSessionOnScreen() throws {
        let store = LapStore(directory: directory)
        try store.write(makeSession(id: LapStore.newID()))

        let game = F1Game(format: .f126)
        let client = TelemetryClient(game: game, store: store)
        let demo = game.makeDemo()!
        for _ in 0..<(60 * 240) {
            demo.nextDatagrams().forEach { _ = game.consume($0, sink: client) }
        }
        XCTAssertFalse(client.showsSavedSession)
        XCTAssertEqual(client.shownLaps, client.dash.completedLaps)
    }

    private func makeSession(id: String) -> StoredSession {
        var info = SessionInfo()
        info.trackID = 10
        info.trackLength = 5_000
        let samples = (0..<40).map { i in
            TraceSample(timeMS: i * 50, distance: Float(i) * 3.5, x: Float(i) * 1.25, z: -Float(i) * 0.5,
                        speedKPH: 200 + i, throttle: 0.75, brake: 0, steer: -0.12, gear: 6, rpm: 11_000,
                        ersStore: 3_500_000, ersDeployed: 120_000.5, overtake: i % 2 == 0, straightMode: false,
                        gLat: 1.33, gLong: -0.25)
        }
        let laps = [
            CompletedLap(number: 1, timeMS: 92_000, sector1MS: 30_000, sector2MS: 31_000, sector3MS: 31_000,
                         invalid: false, date: Date(timeIntervalSince1970: 1_800_000_000)),
            CompletedLap(number: 2, timeMS: 92_500, sector1MS: 31_000, sector2MS: 30_500, sector3MS: 31_000,
                         invalid: false, date: Date(timeIntervalSince1970: 1_800_000_100))
        ]
        return StoredSession(id: id, gameID: F1Game.id, savedAt: Date(timeIntervalSince1970: 1_800_000_200),
                             session: info, laps: laps, traces: [LapTrace(number: 1, timeMS: 92_000, samples: samples)])
    }
}
