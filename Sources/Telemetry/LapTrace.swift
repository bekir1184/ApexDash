import Foundation

/// Tur boyunca 20 Hz ile alinan tek bir telemetri ornegi.
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

/// Tamamlanmis bir turun tum izi. Siteye bir kez gonderilir.
struct LapTrace: Identifiable {
    var id: Int { number }
    let number: Int
    let timeMS: Int
    let samples: [TraceSample]

    /// Kompakt JSON: sutun adlari + sayi dizileri. 90 saniyelik tur ~90 KB.
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

/// Paketlerden gelen son degerleri birlestirip LapData hizinda ornekler;
/// tur numarasi degisince biten turun izini kapatir.
struct TraceRecorder {
    private(set) var traces: [LapTrace] = []
    private var current: [TraceSample] = []
    private var currentLap = 0
    private var lastSampleMS = -1_000
    private let intervalMS = 50

    // Son bilinen degerler
    var motion = CarMotion()
    var telemetry = CarTelemetry()
    var status = CarStatus()
    var telemetry2 = CarTelemetry2()

    mutating func ingest(_ lap: LapData) {
        if lap.currentLapNum != currentLap {
            close(lapNumber: currentLap, timeMS: lap.lastLapTimeMS)
            currentLap = lap.currentLapNum
            current.removeAll(keepingCapacity: true)
            lastSampleMS = -1_000
        }
        guard lap.currentLapTimeMS - lastSampleMS >= intervalMS else { return }
        lastSampleMS = lap.currentLapTimeMS
        current.append(TraceSample(
            timeMS: lap.currentLapTimeMS, distance: lap.lapDistance,
            x: motion.worldX, z: motion.worldZ,
            speedKPH: telemetry.speedKPH, throttle: telemetry.throttle,
            brake: telemetry.brake, steer: telemetry.steer,
            gear: telemetry.gear, rpm: telemetry.engineRPM,
            ersStore: status.ersStoreEnergy, ersDeployed: status.ersDeployedThisLap,
            overtake: telemetry2.overtakeActive, straightMode: telemetry2.aeroMode == .straight,
            gLat: motion.gLateral, gLong: motion.gLongitudinal))
        if current.count > 6_000 { current.removeFirst(1_000) }   // 5 dk ustu turlarda bellek siniri
    }

    private mutating func close(lapNumber: Int, timeMS: Int) {
        guard lapNumber > 0, timeMS > 0, current.count > 20 else { return }
        traces.append(LapTrace(number: lapNumber, timeMS: timeMS, samples: current))
        if traces.count > 60 { traces.removeFirst() }
    }
}
