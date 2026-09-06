import Foundation

/// Ekranin cizdigi tek dogruluk kaynagi. Farkli paketlerden gelen alanlar
/// burada birlestirilir.
struct DashboardModel {
    // CarTelemetry (paket 6)
    var speedKPH: Int = 0
    var gear: Int = 0
    var rpm: Int = 0
    var throttle: Float = 0
    var brake: Float = 0
    var revLightsPercent: Int = 0
    var revLightsBits: UInt16 = 0
    /// Tekerlek dizisi sirasi: RL, RR, FL, FR
    var tyreSurfaceTemps: [Int] = [0, 0, 0, 0]
    var tyreInnerTemps: [Int] = [0, 0, 0, 0]
    var brakeTemps: [Int] = [0, 0, 0, 0]
    var engineTemp: Int = 0

    // CarStatus (paket 7)
    var maxRPM: Int = 15000
    var idleRPM: Int = 4000
    var maxGears: Int = 8
    var pitLimiterOn: Bool = false
    var ersStoreEnergy: Float = 0
    var ersDeployMode: Int = 0
    var fuelRemainingLaps: Float = 0

    // CarTelemetry2 (paket 16) - 2026 kurallari
    var aeroStraightMode: Bool = false
    var aeroAvailable: Bool = false
    var overtakeAvailable: Bool = false
    var overtakeActive: Bool = false
    var is2026Regulations: Bool = false

    // LapData (paket 2)
    var currentLapTimeMS: Int = 0
    var lastLapTimeMS: Int = 0
    var deltaToCarInFrontMS: Int = 0
    var currentLapNum: Int = 0
    var carPosition: Int = 0
    var currentLapInvalid: Bool = false

    var gearLabel: String {
        switch gear {
        case -1: return "R"
        case 0: return "N"
        default: return "\(gear)"
        }
    }

    /// 0...1 arasi, rolanti RPM'i taban alan devir orani.
    var rpmFraction: Double {
        let span = Double(max(maxRPM - idleRPM, 1))
        return min(max(Double(rpm - idleRPM) / span, 0), 1)
    }

    /// Vites degistirme uyarisi: son LED'ler yaninca.
    var shiftFlash: Bool { revLightsPercent >= 97 }

    mutating func apply(_ t: CarTelemetry) {
        speedKPH = t.speedKPH
        gear = t.gear
        rpm = t.engineRPM
        throttle = t.throttle
        brake = t.brake
        revLightsPercent = t.revLightsPercent
        revLightsBits = t.revLightsBits
        tyreSurfaceTemps = t.tyreSurfaceTemps
        tyreInnerTemps = t.tyreInnerTemps
        brakeTemps = t.brakeTemps
        engineTemp = t.engineTemp
    }

    var currentLapTimeText: String { Self.lapTimeText(currentLapTimeMS) }
    var lastLapTimeText: String { Self.lapTimeText(lastLapTimeMS) }

    /// Onundeki araca fark, "+0.34" biciminde.
    var deltaToFrontText: String {
        guard deltaToCarInFrontMS > 0 else { return "--.--" }
        return String(format: "+%.2f", Double(deltaToCarInFrontMS) / 1000)
    }

    /// Ortalama lastik yuzey sicakligi.
    var averageTyreTemp: Int {
        guard !tyreSurfaceTemps.isEmpty else { return 0 }
        return tyreSurfaceTemps.reduce(0, +) / tyreSurfaceTemps.count
    }

    var averageBrakeTemp: Int {
        guard !brakeTemps.isEmpty else { return 0 }
        return brakeTemps.reduce(0, +) / brakeTemps.count
    }

    /// ERS deposunun doluluk orani. Tam depo 4 MJ.
    var ersFraction: Double {
        min(max(Double(ersStoreEnergy) / 4_000_000, 0), 1)
    }

    var ersModeText: String {
        switch ersDeployMode {
        case 1: return "MEDIUM"
        case 2: return "HOTLAP"
        case 3: return "BOOST"
        default: return "NONE"
        }
    }

    static func lapTimeText(_ milliseconds: Int) -> String {
        guard milliseconds > 0 else { return "--:--.---" }
        let minutes = milliseconds / 60_000
        let seconds = (milliseconds % 60_000) / 1000
        let millis = milliseconds % 1000
        return String(format: "%d:%02d.%03d", minutes, seconds, millis)
    }

    mutating func apply(_ l: LapData) {
        currentLapTimeMS = l.currentLapTimeMS
        lastLapTimeMS = l.lastLapTimeMS
        deltaToCarInFrontMS = l.deltaToCarInFrontMS
        currentLapNum = l.currentLapNum
        carPosition = l.carPosition
        currentLapInvalid = l.currentLapInvalid
    }

    mutating func apply(_ s: CarStatus) {
        maxRPM = s.maxRPM
        idleRPM = s.idleRPM
        maxGears = s.maxGears
        pitLimiterOn = s.pitLimiterOn
        ersStoreEnergy = s.ersStoreEnergy
        ersDeployMode = s.ersDeployMode
        fuelRemainingLaps = s.fuelRemainingLaps
    }

    mutating func apply(_ t: CarTelemetry2) {
        aeroStraightMode = t.aeroMode == .straight
        aeroAvailable = t.aeroAvailable
        overtakeAvailable = t.overtakeAvailable
        overtakeActive = t.overtakeActive
        is2026Regulations = t.is2026Regulations
    }
}
