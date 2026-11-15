import Foundation

/// A simulated ACC session that produces the broadcasting messages the game
/// sends after registration, so the app can be tried without the game. Mirrors
/// `Tools/acc_sim.py`, which also answers the registration over the network.
///
/// A GT3 car laps the shared demo circuit with a second car a little ahead,
/// so the gap to the car in front moves.
@MainActor
final class ACCDemoDrive: TelemetryDemo {
    private let track = DemoTrack(topSpeed: 265, grip: 1.7)
    private let rate = 60.0
    private let player = 0, rival = 1

    private var frame = 0
    private var distance = 0.0
    private var speed = 0.0
    private var laps = 0
    private var lapStart = 0.0
    private var lastLapMS: Int?
    private var bestLapMS: Int?
    private var splits: [Int] = []
    /// Total metres the rival has driven, never wrapped.
    private var rivalTotal = 120.0

    func nextDatagrams() -> [Data] {
        let dt = 1 / rate
        let t = Double(frame) * dt
        frame += 1

        // Same driving model as the F1 demo, with GT3 pace.
        let point = track.at(distance)
        let pace = 1 + 0.02 * sin(Double(laps) * 1.7)
        let target = point.targetSpeed / pace
        if speed < target {
            speed = min(target, speed + 26 * dt * (1 - speed / 290))
        } else {
            speed = max(target, speed - 95 * dt)
        }
        distance += speed / 3.6 * dt
        rivalTotal += speed / 3.6 * dt * (1 + 0.012 * sin(t * 0.3))

        let lapMS = Int((t - lapStart) * 1000)
        let sectorLength = track.length / 3
        if splits.count < 2, distance >= sectorLength * Double(splits.count + 1) {
            splits.append(lapMS - splits.reduce(0, +))
        }
        if distance >= track.length {
            distance -= track.length
            splits.append(lapMS - splits.reduce(0, +))
            lastLapMS = lapMS
            bestLapMS = min(bestLapMS ?? .max, lapMS)
            lapStart = t
            laps += 1
            splits = []
        }

        // ACC sends at the registered interval: 50 ms.
        guard frame % 3 == 0 else { return [] }
        var packets: [Data] = []
        if frame % 300 == 3 { packets.append(Self.trackData(name: "demo", length: Int(track.length))) }
        packets.append(Self.realtimeUpdate(focusedCar: player, sessionTimeMS: Float(t * 1000),
                                           bestLapMS: bestLapMS))

        let lapsDriven = Double(laps) + distance / track.length
        let rivalLaps = rivalTotal / track.length
        let rivalAhead = rivalLaps > lapsDriven
        let rivalDistance = rivalTotal.truncatingRemainder(dividingBy: track.length)
        let current = Lap(timeMS: Int((t - lapStart) * 1000), splits: splits.map { Optional($0) })
        packets.append(Self.carUpdate(car: player, gear: gear(for: speed), point: point, speed: speed,
                                      position: rivalAhead ? 2 : 1, spline: distance / track.length, laps: laps,
                                      last: Lap(timeMS: lastLapMS, splits: []),
                                      best: Lap(timeMS: bestLapMS, splits: []), current: current))
        let rivalPoint = track.at(rivalDistance)
        packets.append(Self.carUpdate(car: rival, gear: gear(for: speed), point: rivalPoint, speed: speed,
                                      position: rivalAhead ? 1 : 2, spline: rivalDistance / track.length,
                                      laps: Int(rivalLaps), last: Lap(timeMS: nil, splits: []),
                                      best: Lap(timeMS: nil, splits: []), current: Lap(timeMS: nil, splits: [])))
        return packets
    }

    private func gear(for speed: Double) -> Int {
        speed < 1 ? 1 : max(1, min(6, Int(speed / 48) + 1))
    }

    // MARK: - Encoding (also used by the tests)

    struct Lap {
        var timeMS: Int?
        var splits: [Int?]
    }

    static func registrationResult(connectionID: Int32, success: Bool, error: String = "") -> Data {
        var w = ByteWriter()
        w.uint8(ACCInbound.registrationResult.rawValue)
        w.int32(connectionID)
        w.uint8(success ? 1 : 0)
        w.uint8(1)                      // not read-only
        w.accString(error)
        return w.data
    }

    static func trackData(name: String, length: Int) -> Data {
        var w = ByteWriter()
        w.uint8(ACCInbound.trackData.rawValue)
        w.int32(1)
        w.accString(name)
        w.int32(0)
        w.int32(Int32(length))
        w.uint8(0)                      // camera sets
        w.uint8(0)                      // HUD pages
        return w.data
    }

    static func realtimeUpdate(focusedCar: Int, sessionTimeMS: Float, bestLapMS: Int?,
                               ambient: UInt8 = 22, trackTemp: UInt8 = 29, clouds: UInt8 = 2, rain: UInt8 = 0) -> Data {
        var w = ByteWriter()
        w.uint8(ACCInbound.realtimeUpdate.rawValue)
        w.uint16(0)                     // event index
        w.uint16(0)                     // session index
        w.uint8(0)                      // practice
        w.uint8(5)                      // session phase: session
        w.float(sessionTimeMS)
        w.float(3_600_000)
        w.int32(Int32(focusedCar))
        w.accString("Drivable")
        w.accString("Chase")
        w.accString("Basic HUD")
        w.uint8(0)                      // no replay
        w.float(14 * 3_600_000)
        w.uint8(ambient)
        w.uint8(trackTemp)
        w.uint8(clouds)
        w.uint8(rain)
        w.uint8(0)                      // wetness
        lap(&w, Lap(timeMS: bestLapMS, splits: []), car: focusedCar)
        return w.data
    }

    static func carUpdate(car: Int, gear: Int, point: DemoTrack.Point, speed: Double, position: Int,
                          spline: Double, laps: Int, last: Lap, best: Lap, current: Lap) -> Data {
        var w = ByteWriter()
        w.uint8(ACCInbound.realtimeCarUpdate.rawValue)
        w.uint16(UInt16(car))
        w.uint16(0)                     // driver index
        w.uint8(1)                      // driver count
        w.uint8(UInt8(gear + 2))
        w.float(Float(point.x))
        w.float(Float(point.z))
        w.float(Float(point.yaw))
        w.uint8(UInt8(ACCCarLocation.track.rawValue))
        w.uint16(UInt16(max(0, speed)))
        w.uint16(UInt16(position))
        w.uint16(UInt16(position))      // cup position
        w.uint16(UInt16(position))      // track position
        w.float(Float(spline))
        w.uint16(UInt16(laps))
        w.int32(0)                      // delta
        lap(&w, best, car: car)
        lap(&w, last, car: car)
        lap(&w, current, car: car)
        return w.data
    }

    /// LapInfo: time, car, driver, splits, then four flags.
    static func lap(_ w: inout ByteWriter, _ lap: Lap, car: Int, invalid: Bool = false) {
        w.int32(Int32(lap.timeMS ?? ACCProtocol.noTime))
        w.uint16(UInt16(car))
        w.uint16(0)
        // The game always sends three splits, with "no time" for sectors not driven yet.
        let splits = (0..<3).map { lap.splits.indices.contains($0) ? lap.splits[$0] : nil }
        w.uint8(UInt8(splits.count))
        for split in splits { w.int32(Int32(split ?? ACCProtocol.noTime)) }
        w.uint8(invalid ? 1 : 0)
        w.uint8(invalid ? 0 : 1)        // valid for best
        w.uint8(0)                      // out lap
        w.uint8(0)                      // in lap
    }
}
