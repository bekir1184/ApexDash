import Foundation

/// Assetto Corsa Competizione, through its broadcasting API.
///
/// ACC does not stream on its own: the app registers with the game at the PC's
/// address (the port set in `broadcasting.json`), and the game then sends
/// session and car updates back. The API is meant for broadcast overlays, so it
/// has speed, gear, position, lap and sector times and the car's map position,
/// but no RPM, pedals, tyres or fuel. Those stay at their defaults.
@MainActor
final class ACCGame: TelemetryGame {
    static let id = "acc"
    static let displayName = "Assetto Corsa Competizione"
    /// `updListenerPort` in broadcasting.json. The game ships with it set to 0
    /// (off); 9000 is the value most guides use.
    static let defaultPort: UInt16 = 9000
    static let connectsToGame = true

    /// Shown in the game's list of connected broadcasting clients.
    static let clientName = "Apex Dash"
    /// Realtime update interval. 50 ms matches the 20 Hz lap traces.
    static let updateIntervalMS: Int32 = 50

    /// `connectionPassword` in broadcasting.json.
    let password: String

    private var connectionID: Int32?
    private var lastMessageDate: Date?
    private var lastRegisterDate: Date?
    private var focusedCarIndex: Int?
    private var trackLength = 0
    private var session = SessionInfo()
    private var cars: [Int: ACCCarUpdate] = [:]
    private var timing = LapTiming()
    private var recorder = ACCTraceRecorder()
    /// Lap number shown to `LapTiming`; held back until the finished lap's time arrives.
    private var timingLap = 0
    private var lastLapMSAtLapStart: Int?
    private var deltaSample: (value: Int, date: Date)?

    init(password: String = "") {
        self.password = password
    }

    func reset() {
        connectionID = nil
        lastMessageDate = nil
        lastRegisterDate = nil
        focusedCarIndex = nil
        trackLength = 0
        session = SessionInfo()
        cars = [:]
        timing = LapTiming()
        recorder = ACCTraceRecorder()
        timingLap = 0
        lastLapMSAtLapStart = nil
        deltaSample = nil
    }

    func makeDemo() -> TelemetryDemo? {
        ACCDemoDrive()
    }

    // MARK: - Registration

    /// Registers, and registers again when the game goes quiet (it was
    /// restarted, or forgot the client after a session change).
    func tick(sink: TelemetrySink) {
        timing.clearFlashIfStale(after: 4)
        sink.dash.applyTiming(timing)

        let now = Date()
        let quiet = lastMessageDate.map { now.timeIntervalSince($0) > 3 } ?? true
        let recentlyAsked = lastRegisterDate.map { now.timeIntervalSince($0) < 2 } ?? false
        guard quiet, !recentlyAsked else { return }
        connectionID = nil
        lastRegisterDate = now
        sink.send(ACCRequest.register(displayName: Self.clientName, password: password,
                                      intervalMS: Self.updateIntervalMS))
    }

    // MARK: - Decoding

    func consume(_ data: Data, sink: TelemetrySink) -> Bool {
        guard let type = data.first.flatMap(ACCInbound.init(rawValue:)) else { return false }
        switch type {
        case .registrationResult:
            guard let result = ACCRegistrationResult(data: data) else { return false }
            guard result.success else {
                // Usually a wrong connectionPassword.
                sink.reportUnexpectedFormat(result.error.isEmpty ? "ACC" : result.error)
                return false
            }
            sink.reportUnexpectedFormat(nil)
            connectionID = result.connectionID
            lastMessageDate = Date()
            sink.send(ACCRequest.trackData(connectionID: result.connectionID))
            return false        // a handshake is not live telemetry yet
        case .realtimeUpdate:
            guard let update = ACCRealtimeUpdate(data: data) else { return false }
            apply(update, sink: sink)
        case .realtimeCarUpdate:
            guard let car = ACCCarUpdate(data: data) else { return false }
            apply(car, sink: sink)
        case .trackData:
            guard let track = ACCTrackData(data: data) else { return false }
            trackLength = track.lengthMetres
            session.trackName = Self.trackName(track.name)
            session.trackLength = track.lengthMetres
            sink.publish(session: session)
        case .entryList, .entryListCar, .broadcastingEvent:
            break
        }
        lastMessageDate = Date()
        return true
    }

    private func apply(_ update: ACCRealtimeUpdate, sink: TelemetrySink) {
        focusedCarIndex = update.focusedCarIndex
        var info = session
        info.airTemperature = update.ambientTemp
        info.trackTemperature = update.trackTemp
        info.weather = Self.weather(clouds: update.clouds, rain: update.rainLevel)
        if info != session {
            session = info
            sink.publish(session: info)
        }
        // Without track data the lap distance is unknown; ask again.
        if trackLength == 0, let id = connectionID {
            sink.send(ACCRequest.trackData(connectionID: id))
        }
    }

    private func apply(_ car: ACCCarUpdate, sink: TelemetrySink) {
        cars[car.carIndex] = car
        guard car.carIndex == focusedCarIndex else { return }

        let lap = car.currentLap
        let lastLapMS = car.lastLap.timeMS ?? 0
        let currentLapMS = lap.timeMS ?? 0
        let distance = Float(car.splinePosition) * Float(trackLength > 0 ? trackLength : 1_000)

        sink.dash.speedKPH = car.speedKPH
        sink.dash.gear = car.gear
        sink.dash.maxGears = 6
        sink.dash.carPosition = car.position
        sink.dash.currentLapTimeMS = currentLapMS
        sink.dash.lastLapTimeMS = lastLapMS
        sink.dash.currentLapInvalid = lap.isInvalid
        sink.dash.sector1MS = lap.split(0)
        sink.dash.sector2MS = lap.split(1)
        sink.dash.pitLimiterOn = car.location == .pitlane

        // ACC counts completed laps; the lap being driven is one more. When the
        // count changes, wait for the finished lap's time before closing it.
        let lapNumber = car.laps + 1
        if timingLap == 0 {
            timingLap = lapNumber
            lastLapMSAtLapStart = lastLapMS
        } else if lapNumber != timingLap,
                  lastLapMS != lastLapMSAtLapStart || currentLapMS > 2_000 {
            timingLap = lapNumber
            lastLapMSAtLapStart = lastLapMS
        }
        sink.dash.currentLapNum = timingLap

        let before = recorder.traces.count
        recorder.ingest(lapNumber: timingLap, lastLapTimeMS: lastLapMS, sample: TraceSample(
            timeMS: currentLapMS, distance: distance, x: car.worldX, z: car.worldY,
            speedKPH: car.speedKPH, throttle: 0, brake: 0, steer: 0, gear: car.gear, rpm: 0,
            ersStore: 0, ersDeployed: 0, overtake: false, straightMode: false, gLat: 0, gLong: 0))
        if recorder.traces.count != before { sink.publish(lapTraces: recorder.traces) }

        timing.ingest(lapNumber: timingLap, lastLapTimeMS: lastLapMS, sector: min(lap.completedSectors, 2),
                      sector1MS: lap.split(0), sector2MS: lap.split(1),
                      distance: distance, currentLapTimeMS: currentLapMS)
        sink.dash.applyTiming(timing)

        let gap = gapToCarAhead(of: car)
        sink.dash.deltaToCarInFrontMS = gap
        updateDeltaTrend(gap, sink: sink)
    }

    // MARK: - Helpers

    /// Time to the car one place ahead, estimated from the distance between the
    /// two cars and the player's speed.
    private func gapToCarAhead(of car: ACCCarUpdate) -> Int {
        guard car.position > 1, trackLength > 0, car.speedKPH > 30,
              let ahead = cars.values.first(where: { $0.position == car.position - 1 })
        else { return 0 }
        let laps = Float(ahead.laps) + ahead.splinePosition - Float(car.laps) - car.splinePosition
        guard laps > 0 else { return 0 }
        let metres = laps * Float(trackLength)
        return Int(metres / (Float(car.speedKPH) / 3.6) * 1000)
    }

    private func updateDeltaTrend(_ current: Int, sink: TelemetrySink) {
        guard current > 0 else {
            sink.dash.deltaTrend = 0
            deltaSample = nil
            return
        }
        guard let sample = deltaSample else {
            deltaSample = (current, Date())
            return
        }
        guard Date().timeIntervalSince(sample.date) >= 1 else { return }
        let change = current - sample.value
        sink.dash.deltaTrend = abs(change) < 50 ? 0 : (change < 0 ? -1 : 1)
        deltaSample = (current, Date())
    }

    /// The weather codes the app shares with F1: 0 clear, 1 light cloud,
    /// 2 overcast, 3 light rain, 4 heavy rain.
    static func weather(clouds: Float, rain: Float) -> Int {
        if rain >= 0.5 { return 4 }
        if rain >= 0.1 { return 3 }
        if clouds >= 0.6 { return 2 }
        if clouds >= 0.3 { return 1 }
        return 0
    }

    /// ACC sends track names such as "monza" or "spa_2019"; shown as "Monza", "Spa".
    static func trackName(_ raw: String) -> String {
        let words = raw.split(separator: "_").filter { Int($0) == nil }
        guard !words.isEmpty else { return raw }
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

/// Records one sample every 50 ms and closes the trace when the lap number changes.
struct ACCTraceRecorder {
    private(set) var traces: [LapTrace] = []
    private var current: [TraceSample] = []
    private var currentLap = 0
    private var lastSampleMS = -1_000

    mutating func ingest(lapNumber: Int, lastLapTimeMS: Int, sample: TraceSample) {
        if lapNumber != currentLap {
            if currentLap > 0, lastLapTimeMS > 0, current.count > 20 {
                traces.append(LapTrace(number: currentLap, timeMS: lastLapTimeMS, samples: current))
                if traces.count > 60 { traces.removeFirst() }
            }
            currentLap = lapNumber
            current.removeAll(keepingCapacity: true)
            lastSampleMS = -1_000
        }
        guard sample.timeMS - lastSampleMS >= 45, sample.x != 0 || sample.z != 0 else { return }
        lastSampleMS = sample.timeMS
        current.append(sample)
        if current.count > 6_000 { current.removeFirst(1_000) }
    }
}
