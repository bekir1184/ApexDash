import XCTest
@testable import ApexDash

/// Runs the built-in demo drive through the real F1 decoder, in both formats,
/// and checks that it produces a working session: motion, completed laps with
/// traces, sector times and a track for the analysis page.
@MainActor
final class DemoDriveTests: XCTestCase {

    func testF126DemoProducesLaps() {
        runDemo(format: .f126)
    }

    func testF125DemoProducesLaps() {
        runDemo(format: .f125)
    }

    private func runDemo(format: PacketFormat) {
        let game = F1Game(format: format)
        let client = TelemetryClient(game: game)
        let demo = game.makeDemo()!
        var topSpeed = 0
        var sawActiveAero = false
        var sawDRS = false

        // Four minutes of driving at 60 Hz: enough for two full laps.
        for _ in 0..<(60 * 240) {
            for datagram in demo.nextDatagrams() {
                XCTAssertTrue(game.consume(datagram, sink: client), "demo sent a packet the decoder rejected")
            }
            topSpeed = max(topSpeed, client.dash.speedKPH)
            sawActiveAero = sawActiveAero || client.dash.aeroStraightMode
            sawDRS = sawDRS || client.dash.drsActive
        }

        XCTAssertNil(client.formatWarning)
        XCTAssertGreaterThan(topSpeed, 250)
        XCTAssertGreaterThanOrEqual(client.dash.completedLaps.count, 2)
        XCTAssertGreaterThanOrEqual(client.lapTraces.count, 1)
        let lap = client.dash.completedLaps[0]
        XCTAssertGreaterThan(lap.timeMS, 60_000)
        XCTAssertGreaterThan(lap.sector1MS, 0)
        XCTAssertGreaterThan(lap.sector2MS, 0)
        XCTAssertGreaterThan(client.sessionInfo.trackLength, 4_000)
        XCTAssertGreaterThan(client.dash.player?.name.count ?? 0, 0)
        if format.hasActiveAero {
            XCTAssertTrue(sawActiveAero)
        } else {
            XCTAssertTrue(sawDRS)
        }
    }
}
