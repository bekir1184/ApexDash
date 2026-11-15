import Foundation

/// A simulated F1 session that produces the exact packets the game sends, so
/// the whole app (dashboards, lap timing, traces and the analysis page) can be
/// tried without the game. Mirrors `Tools/f1_sim.py`.
///
/// The car laps a closed circuit built from straights and corners. Target
/// speed comes from each corner's radius, with braking and acceleration
/// limits, so throttle, brake, gears and G forces behave plausibly.
@MainActor
final class F1DemoDrive: TelemetryDemo {
    private let format: PacketFormat
    private let track = DemoTrack()
    private let rate = 60.0
    private let player = 0
    private let maxRPM = 15_000.0, idleRPM = 4_000.0

    private var frame = 0
    private var distance = 0.0
    private var speed = 0.0            // km/h
    private var previousSpeed = 0.0
    private var lapIndex = 0
    private var lapStart = 0.0
    private var lastLapMS = 0
    private var sector1MS = 0, sector2MS = 0
    private var ers = 4_000_000.0
    private var deployedThisLap = 0.0, harvestedThisLap = 0.0
    /// Seconds before lights out; the car waits on the grid meanwhile.
    private let startDelay = 6.0

    init(format: PacketFormat) {
        self.format = format
    }

    private var cars: Int { format.cars }

    func nextDatagrams() -> [Data] {
        let dt = 1 / rate
        let t = Double(frame) * dt
        var packets: [Data] = []
        let racing = t >= startDelay

        let point = track.at(distance)
        // Every lap has a slightly different pace so laps are worth comparing.
        let pace = 1 + 0.025 * sin(Double(lapIndex) * 1.7)
        let target = racing ? point.targetSpeed / pace : 0
        var throttle = 0.0, brake = 0.0
        if speed < target {
            throttle = 1
            speed = min(target, speed + 45 * dt * (1 - speed / 360))
        } else if racing {
            throttle = target < speed - 4 ? 0 : 0.4
            brake = target < speed - 2 ? min(1, 0.5 + (speed - target) / 30) : 0
            speed = max(target, speed - (170 * brake + 12) * dt)
        }

        let metresPerSecond = speed / 3.6
        distance += metresPerSecond * dt
        if distance >= track.length {
            distance -= track.length
            lastLapMS = Int((t - lapStart) * 1000)
            lapStart = t
            lapIndex += 1
            sector1MS = 0; sector2MS = 0
            deployedThisLap = 0; harvestedThisLap = 0
        }
        let lapTimeMS = racing ? Int((t - max(lapStart, startDelay)) * 1000) : 0
        if !racing { lapStart = startDelay }
        let sector = distance < track.length / 3 ? 0 : (distance < 2 * track.length / 3 ? 1 : 2)
        if sector >= 1 && sector1MS == 0 { sector1MS = lapTimeMS }
        if sector >= 2 && sector2MS == 0 { sector2MS = lapTimeMS - sector1MS }

        let gearSpan = 42.0
        let gear = speed < 1 ? 1 : max(1, min(8, Int(speed / gearSpan) + 1))
        let inGear = (speed - Double(gear - 1) * gearSpan) / gearSpan
        let rpm = max(idleRPM, min(maxRPM, idleRPM + (maxRPM - idleRPM) * inGear * 0.9))
        let gLateral = metresPerSecond * metresPerSecond * point.curvature / 9.81
        let gLongitudinal = ((speed - previousSpeed) / 3.6 / dt) / 9.81
        previousSpeed = speed
        let steer = max(-1, min(1, point.curvature * 40))

        // Battery: deploys on full throttle, harvests under braking.
        let straight = point.curvature == 0 && speed > 200
        if throttle > 0.9 && speed > 120 && ers > 300_000 {
            ers -= 120_000 * dt; deployedThisLap += 120_000 * dt
        }
        if brake > 0.2 {
            let gain = 260_000 * brake * dt
            ers = min(4_000_000, ers + gain); harvestedThisLap += gain
        }

        packets.append(telemetry(speed: speed, gear: gear, rpm: rpm, throttle: throttle, brake: brake,
                                 steer: steer, time: t, drs: !format.hasActiveAero && straight))
        packets.append(motion(point: point, metresPerSecond: metresPerSecond,
                              gLateral: gLateral, gLongitudinal: gLongitudinal))

        if Int(t) >= 1, t < startDelay - 0.5, frame % 6 == 0 {
            packets.append(event("STLG", payload: [UInt8(min(5, Int(t)))]))
        } else if t >= startDelay - 0.5, t < startDelay - 0.3, frame % 6 == 0 {
            packets.append(event("LGOT"))
        }
        if frame % 120 == 0 {
            packets.append(participants())
            packets.append(session())
        }
        if frame % 3 == 0 {
            let gapAhead = Int(1_200 + 900 * sin(t * 0.35))
            packets.append(lapData(lapTimeMS: lapTimeMS, lapNumber: lapIndex + 1, gapAhead: gapAhead,
                                   sector: sector))
            packets.append(status(drsAllowed: straight))
            if format.hasActiveAero {
                let phase = distance / track.length
                packets.append(telemetry2(overtakeReady: phase > 0.3,
                                          overtakeActive: phase > 0.45 && phase < 0.6 && straight,
                                          straightMode: straight))
            }
        }
        frame += 1
        return packets
    }

    // MARK: - Packets

    private func header(_ id: PacketID) -> ByteWriter {
        var w = ByteWriter()
        w.uint16(format.rawValue)
        w.uint8(UInt8(format.rawValue % 100))
        w.uint8(1); w.uint8(0); w.uint8(1)
        w.uint8(id.rawValue)
        w.uint64(1_234_567_890)
        w.float(Float(Double(frame) / rate))
        w.uint32(UInt32(frame)); w.uint32(UInt32(frame))
        w.uint8(UInt8(player)); w.uint8(255)
        return w
    }

    private func telemetry(speed: Double, gear: Int, rpm: Double, throttle: Double, brake: Double,
                           steer: Double, time: Double, drs: Bool) -> Data {
        var w = header(.carTelemetry)
        let percent = Int(max(0, min(100, (rpm - idleRPM) / (maxRPM - idleRPM) * 100)))
        let lit = percent * 15 / 100
        let brakeTemp = Int(260 + 640 * brake + 60 * sin(time))
        let tyreTemp = Int(88 + 20 * min(time / 120, 1) + 4 * sin(time * 0.7))
        for car in 0..<cars {
            guard car == player else { w.zeros(format.telemetryStride); continue }
            w.uint16(UInt16(speed)); w.float(Float(throttle)); w.float(Float(steer)); w.float(Float(brake))
            w.uint8(0); w.int8(Int8(gear)); w.uint16(UInt16(rpm)); w.uint8(drs ? 1 : 0)
            w.uint8(UInt8(percent)); w.uint16(lit <= 0 ? 0 : UInt16((1 << lit) - 1))
            for offset in [40, 0, -30, -60] { w.uint16(UInt16(max(brakeTemp + offset, 0))) }
            for offset in [0, 6, -4, 12] { w.uint8(UInt8(max(tyreTemp + offset, 0))) }
            for offset in [8, 14, 3, 19] { w.uint8(UInt8(max(tyreTemp + offset, 0))) }
            if format == .f126 { w.uint8(110) } else { w.uint16(110) }
            for _ in 0..<4 { w.float(23.5) }
            w.zeros(4)
        }
        w.uint8(255); w.uint8(255); w.int8(0)
        return w.data
    }

    private func telemetry2(overtakeReady: Bool, overtakeActive: Bool, straightMode: Bool) -> Data {
        var w = header(.carTelemetry2)
        for car in 0..<cars {
            guard car == player else { w.zeros(10); continue }
            w.uint8(straightMode ? 1 : 0); w.uint8(1); w.uint16(0)
            w.uint8(overtakeReady ? 1 : 0); w.uint8(overtakeActive ? 1 : 0); w.uint16(0)
            w.uint8(1); w.uint8(0)
        }
        return w.data
    }

    private func motion(point: DemoTrack.Point, metresPerSecond: Double,
                        gLateral: Double, gLongitudinal: Double) -> Data {
        var w = header(.motion)
        for car in 0..<cars {
            guard car == player else { w.zeros(format.motionStride); continue }
            w.float(Float(point.x)); w.float(0); w.float(Float(point.z))
            w.float(Float(metresPerSecond * cos(point.yaw))); w.float(0)
            w.float(Float(metresPerSecond * sin(point.yaw)))
            w.int16(Int16(cos(point.yaw) * 32767)); w.int16(0); w.int16(Int16(sin(point.yaw) * 32767))
            w.int16(Int16(-sin(point.yaw) * 32767)); w.int16(0); w.int16(Int16(cos(point.yaw) * 32767))
            if format == .f126 {
                w.int16(Int16(max(-32, min(32, gLateral)) * 1000))
                w.int16(Int16(max(-32, min(32, gLongitudinal)) * 1000))
                w.int16(1000)
            } else {
                w.float(Float(gLateral)); w.float(Float(gLongitudinal)); w.float(1)
            }
            w.float(Float(point.yaw)); w.float(0); w.float(0)
        }
        return w.data
    }

    private func lapData(lapTimeMS: Int, lapNumber: Int, gapAhead: Int, sector: Int) -> Data {
        var w = header(.lapData)
        let positions = [4, 3, 5, 1, 2, 6]
        for car in 0..<cars {
            guard car == player else {
                var other = [UInt8](repeating: 0, count: format.lapStride)
                other[32] = UInt8(car < positions.count ? positions[car] : car + 1)
                w.zeros(0); for byte in other { w.uint8(byte) }
                continue
            }
            w.uint32(UInt32(lastLapMS)); w.uint32(UInt32(lapTimeMS))
            w.uint16(UInt16(sector1MS % 60_000)); w.uint8(UInt8(sector1MS / 60_000))
            w.uint16(UInt16(sector2MS % 60_000)); w.uint8(UInt8(sector2MS / 60_000))
            w.uint16(UInt16(gapAhead)); w.uint8(0)
            w.uint16(1_250); w.uint8(0)
            w.float(Float(distance)); w.float(Float(distance)); w.float(0)
            w.uint8(UInt8(positions[player])); w.uint8(UInt8(lapNumber)); w.uint8(0); w.uint8(0)
            w.uint8(UInt8(sector)); w.uint8(0)
            w.zeros(5)
            w.uint8(5); w.uint8(4); w.uint8(2)
            w.uint8(0); w.uint16(0); w.uint16(0); w.uint8(0)
            w.float(312.5); w.uint8(UInt8(max(lapNumber, 1)))
        }
        w.uint8(255); w.uint8(255)
        return w.data
    }

    private func status(drsAllowed: Bool) -> Data {
        var w = header(.carStatus)
        for car in 0..<cars {
            guard car == player else { w.zeros(format.statusStride); continue }
            w.uint8(1); w.uint8(0); w.uint8(1); w.uint8(55); w.uint8(0)
            w.float(90); w.float(110); w.float(12.5)
            w.uint16(UInt16(maxRPM)); w.uint16(UInt16(idleRPM)); w.uint8(8)
            w.uint8(drsAllowed ? 1 : 0); w.uint16(0)
            w.uint8(18); w.uint8(18); w.uint8(4); w.int8(1)
            w.float(0); w.float(0); w.float(Float(ers))
            w.uint8(2)
            w.float(Float(harvestedThisLap * 0.6)); w.float(Float(harvestedThisLap * 0.4))
            if format == .f126 { w.float(4_000_000) }
            w.float(Float(deployedThisLap)); w.uint8(0)
        }
        return w.data
    }

    private func participants() -> Data {
        var w = header(.participants)
        let names = ["Demo Driver", "Lewis Hamilton", "George Russell", "Max Verstappen",
                     "Charles Leclerc", "Lando Norris"]
        w.uint8(UInt8(cars))
        for car in 0..<cars {
            let start = w.data.count
            w.uint8(0)
            if format == .f126 { w.uint16(UInt16(car)); w.uint16(0); w.uint16(1) }
            else { w.uint8(UInt8(car)); w.uint8(0); w.uint8(1) }
            w.uint8(car == player ? 1 : 0); w.uint8(UInt8(car + 1)); w.uint8(76)
            w.string(car < names.count ? names[car] : "Driver \(car)", size: 32)
            w.uint8(1); w.uint8(1); w.uint16(0); w.uint8(4); w.uint8(1)
            let colour: [UInt8] = car == player ? [0, 210, 190] : [220, 40, 40]
            for byte in colour { w.uint8(byte) }
            w.zeros(9)
            w.pad(to: start + format.participantStride)
        }
        return w.data
    }

    private func session() -> Data {
        var w = header(.session)
        // Clear weather, 38 °C track, 26 °C air, 20 laps, time trial.
        w.uint8(0); w.int8(38); w.int8(26); w.uint8(20)
        w.uint16(UInt16(track.length)); w.uint8(18); w.int8(-1)
        w.pad(to: 926)
        return w.data
    }

    private func event(_ code: String, payload: [UInt8] = []) -> Data {
        var w = header(.event)
        for byte in code.utf8 { w.uint8(byte) }
        for byte in payload { w.uint8(byte) }
        w.pad(to: 45)
        return w.data
    }
}

/// A closed circuit of straights and constant-radius corners, precomputed at
/// one metre resolution.
private struct DemoTrack {
    struct Point {
        let x, z, yaw, curvature, targetSpeed: Double
    }

    let length: Double
    private let points: [Point]

    init() {
        // (length in metres, corner radius or nil for a straight, +1 left / -1 right)
        let segments: [(Double, Double?, Double)] = [
            (700, nil, 0), (90, 60, 1), (220, nil, 0), (140, 120, -1), (380, nil, 0),
            (80, 35, 1), (60, 35, 1), (300, nil, 0), (200, 200, -1), (520, nil, 0),
            (110, 45, -1), (250, nil, 0), (160, 90, 1), (90, 50, 1), (600, nil, 0),
            (140, 70, -1), (180, nil, 0), (130, 55, 1), (150, 110, -1), (390, nil, 0)
        ]
        var raw: [(x: Double, z: Double, k: Double)] = []
        var x = 0.0, z = 0.0, heading = 0.0
        for (segmentLength, radius, sign) in segments {
            for _ in 0..<Int(segmentLength) {
                let k = radius.map { sign / $0 } ?? 0
                heading += k
                x += cos(heading); z += sin(heading)
                raw.append((x, z, k))
            }
        }
        let n = raw.count
        // Spread the closing error along the lap so the circuit joins up.
        let closed = raw.enumerated().map { i, p in
            (x: p.x - x * Double(i) / Double(n), z: p.z - z * Double(i) / Double(n), k: p.k)
        }
        var target = closed.map { $0.k == 0 ? 330.0 : min(330, 3.6 * (3.2 * 9.81 / abs($0.k)).squareRoot()) }
        for i in stride(from: n - 2, through: 0, by: -1) { target[i] = min(target[i], target[i + 1] + 0.55) }
        for i in 1..<n { target[i] = min(target[i], target[i - 1] + 0.22) }

        points = (0..<n).map { i in
            let next = closed[(i + 1) % n]
            return Point(x: closed[i].x, z: closed[i].z,
                         yaw: atan2(next.z - closed[i].z, next.x - closed[i].x),
                         curvature: closed[i].k, targetSpeed: target[i])
        }
        length = Double(n)
    }

    func at(_ distance: Double) -> Point {
        points[Int(distance) % points.count]
    }
}
