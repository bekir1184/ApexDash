import Foundation

/// EA SPORTS F1 25 and F1 26 telemetry.
///
/// The games send a stream of binary packets that share a 29 byte header. The
/// header says which packet it is (telemetry, lap data, status...) and which
/// year's layout it uses. Layout differences between the two years live in
/// `PacketFormat`.
@MainActor
final class F1Game: TelemetryGame {
    static let id = "f1"
    static let displayName = "F1 25 / F1 26"
    static let defaultPort: UInt16 = 20777

    /// The UDP format selected in the app. Packets in another format are
    /// ignored, because their byte layout differs.
    let format: PacketFormat

    private var timing = LapTiming()
    private var recorder = F1TraceRecorder()
    private var participants: [Participant] = []
    private var deltaSample: (value: Int, date: Date)?

    init(format: PacketFormat = .f126) {
        self.format = format
    }

    func reset() {
        timing = LapTiming()
        recorder = F1TraceRecorder()
        participants = []
        deltaSample = nil
    }

    func makeDemo() -> TelemetryDemo? {
        F1DemoDrive(format: format)
    }

    func consume(_ data: Data, sink: TelemetrySink) -> Bool {
        guard let header = PacketHeader(data) else { return false }
        guard header.format == format else {
            sink.reportUnexpectedFormat(header.format.label)
            return false
        }
        sink.reportUnexpectedFormat(nil)

        let index = header.playerCarIndex
        switch header.packetID {
        case .carTelemetry:
            guard let t = CarTelemetry(data: data, carIndex: index, format: format) else { break }
            sink.dash.apply(t, format: format)
            recorder.telemetry = t
        case .carTelemetry2:
            guard format.hasActiveAero,
                  let t = CarTelemetry2(data: data, carIndex: index) else { break }
            sink.dash.apply(t)
            recorder.telemetry2 = t
        case .motion:
            guard let m = CarMotion(data: data, carIndex: index, format: format) else { break }
            recorder.motion = m
            sink.dash.apply(m)
        case .session:
            guard let info = SessionInfo(data: data) else { break }
            sink.publish(session: info)
        case .lapData:
            guard let lap = LapData(data: data, carIndex: index, format: format) else { break }
            applyLap(lap, data: data, sink: sink)
        case .carStatus:
            guard let s = CarStatus(data: data, carIndex: index, format: format) else { break }
            sink.dash.apply(s)
            recorder.status = s
        case .event:
            switch GameEvent(data: data) {
            case .startLights(let count):
                sink.dash.startLights = count
                sink.dash.lightsOutDate = nil
            case .lightsOut:
                sink.dash.startLights = 0
                sink.dash.lightsOutDate = Date()
            default:
                break
            }
        case .participants:
            let list = ParticipantsPacket.parse(data, format: format)
            if !list.isEmpty { participants = list }
        default:
            break
        }
        return true
    }

    func tick(sink: TelemetrySink) {
        if let date = sink.dash.lightsOutDate, Date().timeIntervalSince(date) > 3 {
            sink.dash.lightsOutDate = nil
        }
        timing.clearFlashIfStale(after: 4)
        sink.dash.applyTiming(timing)
    }

    private func applyLap(_ lap: LapData, data: Data, sink: TelemetrySink) {
        sink.dash.apply(lap)
        let before = recorder.traces.count
        recorder.ingest(lap)
        if recorder.traces.count != before { sink.publish(lapTraces: recorder.traces) }
        updateDeltaTrend(lap.deltaToCarInFrontMS, sink: sink)
        timing.ingest(lapNumber: lap.currentLapNum, lastLapTimeMS: lap.lastLapTimeMS, sector: lap.sector,
                      sector1MS: lap.sector1MS, sector2MS: lap.sector2MS,
                      distance: lap.lapDistance, currentLapTimeMS: lap.currentLapTimeMS)
        sink.dash.applyTiming(timing)
        updateRivals(positions: LapData.positions(in: data, format: format),
                     playerPosition: lap.carPosition, sink: sink)
    }

    /// Samples the gap to the car ahead once a second to tell whether it is
    /// growing or shrinking; changes under 50 ms are ignored.
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

    /// Finds the drivers directly ahead of and behind the player.
    private func updateRivals(positions: [Int], playerPosition: Int, sink: TelemetrySink) {
        guard playerPosition > 0, !participants.isEmpty else { return }
        sink.dash.driverAhead = rival(at: playerPosition - 1, positions: positions)
        sink.dash.player = rival(at: playerPosition, positions: positions)
        sink.dash.driverBehind = rival(at: playerPosition + 1, positions: positions)
    }

    private func rival(at position: Int, positions: [Int]) -> Rival? {
        guard position > 0, let index = positions.firstIndex(of: position),
              participants.indices.contains(index)
        else { return nil }
        let participant = participants[index]
        guard !participant.name.isEmpty else { return nil }
        let colour = participant.teamColour ?? (0.35, 0.78, 0.95)
        return Rival(position: position, name: participant.surname,
                     red: colour.red, green: colour.green, blue: colour.blue)
    }
}
