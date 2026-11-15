import XCTest
@testable import ApexDash

/// ACC broadcasting protocol v4: requests the app sends, replies it reads, and
/// the game logic on top (registration, laps, traces), checked byte by byte.
@MainActor
final class ACCPacketTests: XCTestCase {

    // MARK: - Requests

    func testRegisterRequestLayout() {
        let data = ACCRequest.register(displayName: "AB", password: "asd", intervalMS: 50, commandPassword: "")
        var r = ByteReader(data)
        XCTAssertEqual(r.uint8(), 1)                  // REGISTER_COMMAND_APPLICATION
        XCTAssertEqual(r.uint8(), 4)                  // protocol version
        XCTAssertEqual(r.accString(), "AB")
        XCTAssertEqual(r.accString(), "asd")
        XCTAssertEqual(r.int32(), 50)
        XCTAssertEqual(r.accString(), "")
        XCTAssertEqual(r.remaining, 0)
        XCTAssertEqual(data.count, 1 + 1 + (2 + 2) + (2 + 3) + 4 + 2)
    }

    func testTrackDataRequestLayout() {
        XCTAssertEqual(Array(ACCRequest.trackData(connectionID: 7)), [11, 7, 0, 0, 0])
        XCTAssertEqual(Array(ACCRequest.entryList(connectionID: 7)), [10, 7, 0, 0, 0])
    }

    // MARK: - Replies

    func testRegistrationResult() throws {
        let ok = try XCTUnwrap(ACCRegistrationResult(data: ACCDemoDrive.registrationResult(connectionID: 12, success: true)))
        XCTAssertEqual(ok.connectionID, 12)
        XCTAssertTrue(ok.success)
        XCTAssertFalse(ok.isReadOnly)

        let refused = try XCTUnwrap(ACCRegistrationResult(
            data: ACCDemoDrive.registrationResult(connectionID: 0, success: false, error: "Wrong password")))
        XCTAssertFalse(refused.success)
        XCTAssertEqual(refused.error, "Wrong password")
    }

    func testRealtimeUpdate() throws {
        let data = ACCDemoDrive.realtimeUpdate(focusedCar: 3, sessionTimeMS: 61_000, bestLapMS: 105_123,
                                               ambient: 18, trackTemp: 31, clouds: 7, rain: 2)
        let update = try XCTUnwrap(ACCRealtimeUpdate(data: data))
        XCTAssertEqual(update.focusedCarIndex, 3)
        XCTAssertEqual(update.sessionTimeMS, 61_000)
        XCTAssertEqual(update.ambientTemp, 18)
        XCTAssertEqual(update.trackTemp, 31)
        XCTAssertEqual(update.clouds, 0.7, accuracy: 0.001)
        XCTAssertEqual(update.rainLevel, 0.2, accuracy: 0.001)
        XCTAssertEqual(update.bestSessionLap.timeMS, 105_123)
        XCTAssertNil(ACCRealtimeUpdate(data: data.prefix(data.count - 1)))
    }

    func testRealtimeUpdateSkipsReplayTimes() throws {
        // Same message with the replay flag set and its two floats inserted.
        var w = ByteWriter()
        w.uint8(2); w.uint16(1); w.uint16(2); w.uint8(4); w.uint8(5)
        w.float(1_000); w.float(2_000); w.int32(9)
        w.accString("set"); w.accString("cam"); w.accString("hud")
        w.uint8(1); w.float(123); w.float(456)
        w.float(50_000); w.uint8(20); w.uint8(25); w.uint8(0); w.uint8(0); w.uint8(0)
        ACCDemoDrive.lap(&w, .init(timeMS: nil, splits: []), car: 9)
        let update = try XCTUnwrap(ACCRealtimeUpdate(data: w.data))
        XCTAssertEqual(update.focusedCarIndex, 9)
        XCTAssertEqual(update.trackTemp, 25)
        XCTAssertNil(update.bestSessionLap.timeMS)
    }

    func testCarUpdate() throws {
        let point = DemoTrack.Point(x: 120.5, z: -40.25, yaw: 1.5, curvature: 0, targetSpeed: 200)
        let data = ACCDemoDrive.carUpdate(
            car: 3, gear: -1, point: point, speed: 187, position: 4, spline: 0.25, laps: 6,
            last: .init(timeMS: 104_500, splits: [35_000, 34_500, 35_000]),
            best: .init(timeMS: 104_000, splits: []),
            current: .init(timeMS: 40_250, splits: [34_900]))
        let car = try XCTUnwrap(ACCCarUpdate(data: data))
        XCTAssertEqual(car.carIndex, 3)
        XCTAssertEqual(car.gear, -1)                  // raw 1: reverse
        XCTAssertEqual(car.worldX, 120.5)
        XCTAssertEqual(car.worldY, -40.25)
        XCTAssertEqual(car.location, .track)
        XCTAssertEqual(car.speedKPH, 187)
        XCTAssertEqual(car.position, 4)
        XCTAssertEqual(car.splinePosition, 0.25)
        XCTAssertEqual(car.laps, 6)
        XCTAssertEqual(car.lastLap.timeMS, 104_500)
        XCTAssertEqual(car.lastLap.splits, [35_000, 34_500, 35_000])
        XCTAssertEqual(car.bestSessionLap.timeMS, 104_000)
        XCTAssertEqual(car.currentLap.timeMS, 40_250)
        XCTAssertEqual(car.currentLap.splits, [34_900, nil, nil])
        XCTAssertEqual(car.currentLap.completedSectors, 1)
        XCTAssertEqual(car.currentLap.split(1), 0)
    }

    func testTrackData() throws {
        let track = try XCTUnwrap(ACCTrackData(data: ACCDemoDrive.trackData(name: "spa_2019", length: 7_004)))
        XCTAssertEqual(track.name, "spa_2019")
        XCTAssertEqual(track.lengthMetres, 7_004)
        XCTAssertEqual(ACCGame.trackName("spa_2019"), "Spa")
        XCTAssertEqual(ACCGame.trackName("brands_hatch"), "Brands Hatch")
    }

    // MARK: - Game

    func testRegistersWhenQuietAndAsksForTrack() throws {
        let game = ACCGame(password: "secret")
        let sink = RecordingSink()
        game.tick(sink: sink)
        let register = try XCTUnwrap(sink.sent.first)
        var r = ByteReader(register)
        XCTAssertEqual(r.uint8(), 1)
        XCTAssertEqual(r.uint8(), 4)
        XCTAssertEqual(r.accString(), ACCGame.clientName)
        XCTAssertEqual(r.accString(), "secret")

        // No second request while waiting for the reply.
        game.tick(sink: sink)
        XCTAssertEqual(sink.sent.count, 1)

        XCTAssertFalse(game.consume(ACCDemoDrive.registrationResult(connectionID: 5, success: true), sink: sink))
        XCTAssertEqual(sink.sent.last.map(Array.init), [11, 5, 0, 0, 0])
        XCTAssertNil(sink.warning)
    }

    func testRefusedRegistrationIsReported() {
        let game = ACCGame(password: "wrong")
        let sink = RecordingSink()
        _ = game.consume(ACCDemoDrive.registrationResult(connectionID: 0, success: false, error: "Wrong password"),
                         sink: sink)
        XCTAssertEqual(sink.warning, "Wrong password")
    }

    func testIgnoresOtherGames() {
        let sink = RecordingSink()
        XCTAssertFalse(ACCGame().consume(Data([0xE9, 0x07, 0x1A]), sink: sink))
        XCTAssertFalse(ACCGame().consume(Data(), sink: sink))
    }

    func testDemoProducesLapsTracesAndTrack() {
        let game = ACCGame()
        let client = TelemetryClient(game: game, store: nil)
        let demo = game.makeDemo()!
        var topSpeed = 0, sawGap = false, maxGear = 0

        // Five minutes at 60 Hz: enough for two full laps.
        for _ in 0..<(60 * 300) {
            for datagram in demo.nextDatagrams() {
                XCTAssertTrue(game.consume(datagram, sink: client), "demo sent a message the decoder rejected")
            }
            topSpeed = max(topSpeed, client.dash.speedKPH)
            maxGear = max(maxGear, client.dash.gear)
            sawGap = sawGap || client.dash.deltaToCarInFrontMS > 0
        }

        XCTAssertGreaterThan(topSpeed, 200)
        XCTAssertEqual(maxGear, 6)
        XCTAssertTrue(sawGap)
        XCTAssertEqual(client.dash.carPosition, 2)
        XCTAssertEqual(client.sessionInfo.trackName, "Demo")
        XCTAssertGreaterThan(client.sessionInfo.trackLength, 4_000)
        XCTAssertGreaterThanOrEqual(client.dash.completedLaps.count, 2)
        XCTAssertGreaterThanOrEqual(client.lapTraces.count, 1)

        // The second lap starts at the line, so its time and sectors are whole.
        let lap = client.dash.completedLaps[1]
        XCTAssertGreaterThan(lap.timeMS, 60_000)
        XCTAssertGreaterThan(lap.sector1MS, 0)
        XCTAssertGreaterThan(lap.sector2MS, 0)
        XCTAssertEqual(lap.sector1MS + lap.sector2MS + lap.sector3MS, lap.timeMS)
        XCTAssertGreaterThan(client.lapTraces[0].samples.count, 500)
    }

    func testGameAddressParsing() {
        XCTAssertEqual(TelemetryClient.endpoint("192.168.1.20", defaultPort: 9000).map { "\($0.0):\($0.1)" },
                       "192.168.1.20:9000")
        XCTAssertEqual(TelemetryClient.endpoint("10.0.0.5:9100", defaultPort: 9000).map { "\($0.1)" }, "9100")
        XCTAssertNil(TelemetryClient.endpoint("", defaultPort: 9000))
        XCTAssertNil(TelemetryClient.endpoint("10.0.0.5:abc", defaultPort: 9000))
    }

    func testGameChoiceBuildsTheRightGame() {
        XCTAssertTrue(GameChoice.resolve("acc").make(f1Format: 2026, accPassword: "x") is ACCGame)
        XCTAssertTrue(GameChoice.resolve("f1").make(f1Format: 2025, accPassword: "") is F1Game)
        XCTAssertEqual(GameChoice.resolve("unknown"), .f1)
    }
}

/// Collects what a game publishes and sends.
@MainActor
private final class RecordingSink: TelemetrySink {
    var dash = DashboardModel()
    var sent: [Data] = []
    var warning: String?
    var traces: [LapTrace] = []
    var session = SessionInfo()

    func publish(lapTraces: [LapTrace]) { traces = lapTraces }
    func publish(session: SessionInfo) { self.session = session }
    func reportUnexpectedFormat(_ description: String?) { warning = description }
    func send(_ data: Data) { sent.append(data) }
}
