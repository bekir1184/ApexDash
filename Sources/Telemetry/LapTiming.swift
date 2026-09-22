import Foundation

/// A completed lap. The CSV export is built from these records.
struct CompletedLap: Identifiable, Equatable {
    let id = UUID()
    let number: Int
    let timeMS: Int
    let sector1MS: Int
    let sector2MS: Int
    let sector3MS: Int
    let invalid: Bool
    let date: Date
}

/// Sector colours. With a single car tracked, purple means the session best and green means
/// equal to or faster than the same sector of the best lap.
enum SectorColour {
    case purple, green, yellow, none
}

/// Shown large for a moment after a sector is completed.
struct SectorFlash: Equatable {
    let index: Int          // 0, 1, 2
    let timeMS: Int
    let colour: SectorColour
    let date: Date
}

/// Live delta to the best lap, sector times and the lap log.
///
/// The delta comes from the best lap's distance-to-time trace: find how long the reference
/// lap took to reach the current distance and take the difference.
struct LapTiming {
    private struct Sample {
        let distance: Float
        let timeMS: Int
    }

    /// Trace sampling: no more than one sample per this many metres.
    private static let sampleStep: Float = 8

    private var currentSamples: [Sample] = []
    private var referenceSamples: [Sample] = []
    private var lastLapNumber = 0
    private var lastSector = 0
    private var lastSeenSector1MS = 0
    private var lastSeenSector2MS = 0

    private(set) var bestLapMS = 0
    private(set) var bestSectorMS: [Int] = [0, 0, 0]
    private(set) var laps: [CompletedLap] = []
    private(set) var lastLap: CompletedLap?
    private(set) var sectorFlash: SectorFlash?
    /// Gap to the best lap (ms). nil without a reference lap.
    private(set) var deltaToBestMS: Int?

    var hasReference: Bool { !referenceSamples.isEmpty }

    /// Feeds the current lap state. Call it every time the game reports lap progress.
    /// - Parameters:
    ///   - lapNumber: the lap being driven now; a change closes the previous lap.
    ///   - lastLapTimeMS: time of the lap that just finished.
    ///   - sector: zero based sector being driven now.
    ///   - sector1MS, sector2MS: sector times of the current lap so far.
    ///   - distance: metres from the start line.
    ///   - currentLapTimeMS: time into the current lap.
    mutating func ingest(lapNumber: Int, lastLapTimeMS: Int, sector: Int,
                         sector1MS: Int, sector2MS: Int, distance: Float, currentLapTimeMS: Int) {
        if lapNumber != lastLapNumber {
            closeLap(previousNumber: lastLapNumber, lastLapTimeMS: lastLapTimeMS)
            lastLapNumber = lapNumber
            lastSector = 0
        }

        if sector != lastSector {
            flashSector(finished: lastSector, times: [sector1MS, sector2MS])
            lastSector = sector
        }

        lastSeenSector1MS = sector1MS
        lastSeenSector2MS = sector2MS

        record(distance: distance, timeMS: currentLapTimeMS)
        deltaToBestMS = delta(at: distance, timeMS: currentLapTimeMS)
    }

    /// Records the lap that just ended and updates the reference if it was faster.
    private mutating func closeLap(previousNumber: Int, lastLapTimeMS: Int) {
        defer { currentSamples.removeAll(keepingCapacity: true) }

        guard previousNumber > 0, lastLapTimeMS > 0 else { return }
        let sector3 = max(lastLapTimeMS - lastSeenSector1MS - lastSeenSector2MS, 0)
        let lap = CompletedLap(number: previousNumber,
                               timeMS: lastLapTimeMS,
                               sector1MS: lastSeenSector1MS,
                               sector2MS: lastSeenSector2MS,
                               sector3MS: sector3,
                               invalid: false,
                               date: Date())
        laps.append(lap)
        lastLap = lap

        for (index, value) in [lap.sector1MS, lap.sector2MS, lap.sector3MS].enumerated()
        where value > 0 && (bestSectorMS[index] == 0 || value < bestSectorMS[index]) {
            bestSectorMS[index] = value
        }

        // Only a lap recorded from its start can become the reference; if the app was
        // opened mid-lap, that lap's trace is incomplete.
        let complete = (currentSamples.first?.distance ?? .greatestFiniteMagnitude) < 200
        if complete, bestLapMS == 0 || lastLapTimeMS < bestLapMS {
            bestLapMS = lastLapTimeMS
            referenceSamples = currentSamples
        }
    }

    private mutating func flashSector(finished sector: Int, times: [Int]) {
        guard sector < times.count, times[sector] > 0 else { return }
        let value = times[sector]
        sectorFlash = SectorFlash(index: sector,
                                  timeMS: value,
                                  colour: colour(forSector: sector, time: value),
                                  date: Date())
    }

    func colour(forSector index: Int, time: Int) -> SectorColour {
        guard time > 0 else { return .none }
        let best = bestSectorMS.indices.contains(index) ? bestSectorMS[index] : 0
        if best == 0 || time < best { return .purple }
        if time == best { return .green }
        return .yellow
    }

    private mutating func record(distance: Float, timeMS: Int) {
        guard distance >= 0, timeMS > 0 else { return }
        if let last = currentSamples.last {
            guard distance - last.distance >= Self.sampleStep else { return }
        }
        currentSamples.append(Sample(distance: distance, timeMS: timeMS))
    }

    /// The difference to the reference lap's time at the given distance.
    private func delta(at distance: Float, timeMS: Int) -> Int? {
        guard !referenceSamples.isEmpty, distance >= 0, timeMS > 0 else { return nil }
        guard distance >= referenceSamples[0].distance,
              let index = referenceSamples.firstIndex(where: { $0.distance >= distance }),
              index > 0
        else { return nil }

        let after = referenceSamples[index]
        let before = referenceSamples[index - 1]
        let span = after.distance - before.distance
        let ratio = span > 0 ? Double((distance - before.distance) / span) : 0
        let referenceTime = Double(before.timeMS) + ratio * Double(after.timeMS - before.timeMS)
        return timeMS - Int(referenceTime)
    }

    mutating func clearFlashIfStale(after seconds: TimeInterval) {
        if let flash = sectorFlash, Date().timeIntervalSince(flash.date) > seconds {
            sectorFlash = nil
        }
    }
}
