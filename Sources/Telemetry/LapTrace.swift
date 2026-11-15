import Foundation

/// One telemetry sample, recorded at 20 Hz during a lap. Games fill in what
/// they have; missing channels stay zero.
struct TraceSample: Equatable {
    var timeMS: Int
    var distance: Float
    var x: Float
    var z: Float
    var speedKPH: Int
    var throttle: Float
    var brake: Float
    var steer: Float
    var gear: Int
    var rpm: Int
    var ersStore: Float
    var ersDeployed: Float
    var overtake: Bool
    var straightMode: Bool
    var gLat: Float
    var gLong: Float
}

/// The full trace of a completed lap, served to the analysis page.
struct LapTrace: Identifiable, Equatable {
    var id: Int { number }
    let number: Int
    let timeMS: Int
    let samples: [TraceSample]

    /// Compact JSON: column names plus rows of numbers. A 90 second lap is about 90 KB.
    func payload() -> [String: Any] {
        [
            "lap": number,
            "time": timeMS,
            "columns": ["t", "d", "x", "z", "v", "th", "br", "st", "g", "rpm", "ers", "dep", "ov", "ae", "gl", "gg"],
            "rows": samples.map { s -> [Double] in
                [Double(s.timeMS), round1(s.distance), round1(s.x), round1(s.z), Double(s.speedKPH),
                 round2(s.throttle), round2(s.brake), round2(s.steer), Double(s.gear), Double(s.rpm),
                 Double(Int(s.ersStore / 1000)), Double(Int(s.ersDeployed / 1000)),
                 s.overtake ? 1 : 0, s.straightMode ? 1 : 0, round2(s.gLat), round2(s.gLong)]
            }
        ]
    }

    private func round1(_ v: Float) -> Double { (Double(v) * 10).rounded() / 10 }
    private func round2(_ v: Float) -> Double { (Double(v) * 100).rounded() / 100 }
}

// MARK: - Storage

extension TraceSample: Codable {
    /// Stored as a bare array in field order, so a saved lap stays small.
    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        timeMS = try c.decode(Int.self)
        distance = try c.decode(Float.self)
        x = try c.decode(Float.self)
        z = try c.decode(Float.self)
        speedKPH = try c.decode(Int.self)
        throttle = try c.decode(Float.self)
        brake = try c.decode(Float.self)
        steer = try c.decode(Float.self)
        gear = try c.decode(Int.self)
        rpm = try c.decode(Int.self)
        ersStore = try c.decode(Float.self)
        ersDeployed = try c.decode(Float.self)
        overtake = try c.decode(Int.self) != 0
        straightMode = try c.decode(Int.self) != 0
        gLat = try c.decode(Float.self)
        gLong = try c.decode(Float.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(timeMS)
        try c.encode(distance)
        try c.encode(x)
        try c.encode(z)
        try c.encode(speedKPH)
        try c.encode(throttle)
        try c.encode(brake)
        try c.encode(steer)
        try c.encode(gear)
        try c.encode(rpm)
        try c.encode(ersStore)
        try c.encode(ersDeployed)
        try c.encode(overtake ? 1 : 0)
        try c.encode(straightMode ? 1 : 0)
        try c.encode(gLat)
        try c.encode(gLong)
    }
}

extension LapTrace: Codable {}
