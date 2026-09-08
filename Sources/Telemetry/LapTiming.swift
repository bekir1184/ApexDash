import Foundation

/// Tamamlanmis bir tur. CSV disa aktarimi da bu kayitlardan uretilir.
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

/// Sektor renkleri. Tek arac takip ettigimiz icin "mor" seansin en iyisi,
/// "yesil" en iyi turdaki ayni sektore esit ya da ondan hizli demek.
enum SectorColour {
    case purple, green, yellow, none
}

/// Sektor gecildikten sonra kisa sure buyuk gosterilen bilgi.
struct SectorFlash: Equatable {
    let index: Int          // 0, 1, 2
    let timeMS: Int
    let colour: SectorColour
    let date: Date
}

/// En iyi tura gore canli delta, sektor sureleri ve tur kaydi.
///
/// Delta, en iyi turun "mesafe -> sure" izinden uretilir: su anki mesafede
/// referans turun ne kadar surede oldugu bulunup aradaki fark alinir.
struct LapTiming {
    private struct Sample {
        let distance: Float
        let timeMS: Int
    }

    /// Iz orneklemesi: bu mesafe araligindan sik ornek alinmaz.
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
    /// En iyi tura gore fark (ms). Referans tur yoksa nil.
    private(set) var deltaToBestMS: Int?

    var hasReference: Bool { !referenceSamples.isEmpty }

    mutating func ingest(_ lap: LapData) {
        if lap.currentLapNum != lastLapNumber {
            closeLap(previousNumber: lastLapNumber, lastLapTimeMS: lap.lastLapTimeMS)
            lastLapNumber = lap.currentLapNum
            lastSector = 0
        }

        if lap.sector != lastSector {
            flashSector(finished: lastSector, lap: lap)
            lastSector = lap.sector
        }

        lastSeenSector1MS = lap.sector1MS
        lastSeenSector2MS = lap.sector2MS

        record(distance: lap.lapDistance, timeMS: lap.currentLapTimeMS)
        deltaToBestMS = delta(at: lap.lapDistance, timeMS: lap.currentLapTimeMS)
    }

    /// Yeni tur baslarken kapanan turu kaydeder, gerekiyorsa referansi gunceller.
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

        // Referans ancak bastan izlenmis bir turdan alinir; uygulama tur
        // ortasinda acildiysa o turun izi eksiktir.
        let complete = (currentSamples.first?.distance ?? .greatestFiniteMagnitude) < 200
        if complete, bestLapMS == 0 || lastLapTimeMS < bestLapMS {
            bestLapMS = lastLapTimeMS
            referenceSamples = currentSamples
        }
    }

    private mutating func flashSector(finished sector: Int, lap: LapData) {
        let times = [lap.sector1MS, lap.sector2MS]
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

    /// Referans turun verilen mesafedeki suresi ile aradaki fark.
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
