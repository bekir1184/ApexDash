import Foundation

/// Combines the latest values from F1 packets into one sample at Lap Data
/// rate, and closes the trace when the lap number changes.
struct F1TraceRecorder {
    private(set) var traces: [LapTrace] = []
    private var current: [TraceSample] = []
    private var currentLap = 0
    private var lastSampleMS = -1_000
    private let intervalMS = 50

    // Latest values seen
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
        guard lap.currentLapTimeMS - lastSampleMS >= intervalMS,
              motion.worldX != 0 || motion.worldZ != 0     // no position yet, nothing to record
        else { return }
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
        if current.count > 6_000 { current.removeFirst(1_000) }   // caps memory on laps longer than five minutes
    }

    private mutating func close(lapNumber: Int, timeMS: Int) {
        guard lapNumber > 0, timeMS > 0, current.count > 20 else { return }
        traces.append(LapTrace(number: lapNumber, timeMS: timeMS, samples: current))
        if traces.count > 60 { traces.removeFirst() }
    }
}
