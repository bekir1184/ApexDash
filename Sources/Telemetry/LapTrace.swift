import Foundation

/// One telemetry sample, recorded at 20 Hz during a lap. Games fill in what
/// they have; missing channels stay zero.
struct TraceSample {
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
struct LapTrace: Identifiable {
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
