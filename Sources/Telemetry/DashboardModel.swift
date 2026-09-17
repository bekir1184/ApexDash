import Foundation

/// The driver ahead or behind.
struct Rival: Equatable {
    let position: Int
    let name: String
    let red: Double
    let green: Double
    let blue: Double
}

/// The single source of truth the dashboards draw. Fields from different packets and games
/// are combined here.
struct DashboardModel {
    // Car telemetry
    var speedKPH: Int = 0
    var gear: Int = 0
    var rpm: Int = 0
    var throttle: Float = 0
    var brake: Float = 0
    var revLightsPercent: Int = 0
    var revLightsBits: UInt16 = 0
    /// Wheel order: RL, RR, FL, FR
    var tyreSurfaceTemps: [Int] = [0, 0, 0, 0]
    var tyreInnerTemps: [Int] = [0, 0, 0, 0]
    var brakeTemps: [Int] = [0, 0, 0, 0]
    var engineTemp: Int = 0

    // Car status
    var maxRPM: Int = 15000
    var idleRPM: Int = 4000
    var maxGears: Int = 8
    var pitLimiterOn: Bool = false
    var ersStoreEnergy: Float = 0
    var ersDeployMode: Int = 0
    var fuelRemainingLaps: Float = 0
    /// FIA flag: -1 unknown, 0 none, 1 green, 2 blue, 3 yellow
    var fiaFlag: Int = -1
    /// Direction of the energy store: +1 harvesting (recharge), -1 deploying, 0 steady.
    /// Derived from consecutive car status updates.
    var ersTrend: Int = 0
    var ersHarvestedThisLap: Float = 0
    var ersHarvestLimitPerLap: Float = 0
    var ersDeployedThisLap: Float = 0

    // Active aero and overtake (2026 regulations)
    var aeroStraightMode: Bool = false
    var aeroAvailable: Bool = false
    var overtakeAvailable: Bool = false
    var overtakeActive: Bool = false
    var is2026Regulations: Bool = false
    /// DRS is shown for F1 25; active aero under the 2026 regulations.
    var usesDRS: Bool = false
    var drsActive: Bool = false
    var drsAllowed: Bool = false

    // Motion
    //
    // Lateral and longitudinal G force; right and forward are positive.
    var gLateral: Float = 0
    var gLongitudinal: Float = 0

    // Lap data
    var currentLapTimeMS: Int = 0
    var lastLapTimeMS: Int = 0
    var deltaToCarInFrontMS: Int = 0
    /// Trend of the gap to the car ahead: -1 closing, +1 dropping back, 0 steady.
    var deltaTrend: Int = 0
    var currentLapNum: Int = 0
    var carPosition: Int = 0
    var currentLapInvalid: Bool = false

    // Lap timing (LapTiming)
    var sector1MS: Int = 0
    var sector2MS: Int = 0
    var bestLapMS: Int = 0
    var bestSectorMS: [Int] = [0, 0, 0]
    /// Gap to the best lap (ms); nil until a reference lap exists.
    var deltaToBestMS: Int?
    var lastLap: CompletedLap?
    var sectorFlash: SectorFlash?
    var completedLaps: [CompletedLap] = []

    /// Race start: number of lit lights (0-5) and when they went out.
    var startLights: Int = 0
    var lightsOutDate: Date?

    /// For the name plates of the broadcast dashboard.
    var driverAhead: Rival?
    var player: Rival?
    var driverBehind: Rival?

    // MARK: - Labels that depend on the regulations
    //
    // F1 25 has DRS; the 2026 regulations replace it with overtake mode and active aero.
    // Dashboards read these properties and never need to know which game is connected.

    /// Power badge: OVERTAKE in 2026, DRS in F1 25.
    var boostLabel: String { usesDRS ? "DRS" : "OVERTAKE" }
    var boostActive: Bool { usesDRS ? drsActive : overtakeActive }
    var boostAvailable: Bool { usesDRS ? drsAllowed : overtakeAvailable }

    /// Aero badge: wing mode in 2026, DRS again in F1 25.
    var aeroLabel: String { usesDRS ? "DRS" : (aeroStraightMode ? "AERO Z" : "AERO X") }
    var aeroEngaged: Bool { usesDRS ? drsActive : aeroStraightMode }
    var aeroReady: Bool { usesDRS ? drsAllowed : aeroAvailable }
    /// Long label: the row title on the broadcast and dot matrix dashboards.
    var aeroTitle: String { usesDRS ? "DRS" : "ACTIVE AERO" }

    var gearLabel: String {
        switch gear {
        case -1: return "R"
        case 0: return "N"
        default: return "\(gear)"
        }
    }

    /// RPM as 0...1, measured from idle.
    var rpmFraction: Double {
        let span = Double(max(maxRPM - idleRPM, 1))
        return min(max(Double(rpm - idleRPM) / span, 0), 1)
    }

    /// Shift warning: the last LEDs are lit.
    var shiftFlash: Bool { revLightsPercent >= 97 }

    var currentLapTimeText: String { Self.lapTimeText(currentLapTimeMS) }
    var lastLapTimeText: String { Self.lapTimeText(lastLapTimeMS) }

    /// Gap to the car ahead, formatted as "+0.34".
    var deltaToFrontText: String {
        guard deltaToCarInFrontMS > 0 else { return "--.--" }
        return String(format: "+%.2f", Double(deltaToCarInFrontMS) / 1000)
    }

    /// Average tyre surface temperature.
    var averageTyreTemp: Int {
        guard !tyreSurfaceTemps.isEmpty else { return 0 }
        return tyreSurfaceTemps.reduce(0, +) / tyreSurfaceTemps.count
    }

    var averageBrakeTemp: Int {
        guard !brakeTemps.isEmpty else { return 0 }
        return brakeTemps.reduce(0, +) / brakeTemps.count
    }

    /// How full the ERS store is. A full store holds 4 MJ.
    var ersFraction: Double {
        min(max(Double(ersStoreEnergy) / 4_000_000, 0), 1)
    }

    /// Energy harvested this lap as a share of the lap limit, or of the battery capacity
    /// when no limit is known.
    var harvestFraction: Double {
        let limit = ersHarvestLimitPerLap > 0 ? ersHarvestLimitPerLap : 4_000_000
        return min(max(Double(ersHarvestedThisLap / limit), 0), 1)
    }

    /// Energy deployed this lap as a share of the lap limit.
    var deployedFraction: Double {
        guard ersHarvestLimitPerLap > 0 else { return 0 }
        return min(max(Double(ersDeployedThisLap / ersHarvestLimitPerLap), 0), 1)
    }

    var ersModeText: String {
        switch ersDeployMode {
        case 1: return "MEDIUM"
        case 2: return "HOTLAP"
        case 3: return "BOOST"
        default: return "NONE"
        }
    }

    /// Signed delta formatted as "-0.284".
    var deltaToBestText: String {
        guard let delta = deltaToBestMS else { return "--.---" }
        return String(format: "%+.3f", Double(delta) / 1000)
    }

    var bestLapText: String { Self.lapTimeText(bestLapMS) }

    /// Sector time formatted as "31.205"; over a minute it uses the full lap format.
    static func sectorText(_ milliseconds: Int) -> String {
        guard milliseconds > 0 else { return "--.---" }
        if milliseconds >= 60_000 { return lapTimeText(milliseconds) }
        return String(format: "%.3f", Double(milliseconds) / 1000)
    }

    static func lapTimeText(_ milliseconds: Int) -> String {
        guard milliseconds > 0 else { return "--:--.---" }
        let minutes = milliseconds / 60_000
        let seconds = (milliseconds % 60_000) / 1000
        let millis = milliseconds % 1000
        return String(format: "%d:%02d.%03d", minutes, seconds, millis)
    }

    mutating func applyTiming(_ timing: LapTiming) {
        bestLapMS = timing.bestLapMS
        bestSectorMS = timing.bestSectorMS
        deltaToBestMS = timing.deltaToBestMS
        lastLap = timing.lastLap
        sectorFlash = timing.sectorFlash
        completedLaps = timing.laps
    }

}
