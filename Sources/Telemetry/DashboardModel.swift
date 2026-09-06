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

    // CarStatus (paket 7)
    var maxRPM: Int = 15000
    var idleRPM: Int = 4000
    var maxGears: Int = 8
    var pitLimiterOn: Bool = false

    // CarTelemetry2 (paket 16) - 2026 kurallari
    var aeroStraightMode: Bool = false
    var aeroAvailable: Bool = false
    var overtakeAvailable: Bool = false
    var overtakeActive: Bool = false
    var is2026Regulations: Bool = false

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
    }

    mutating func apply(_ s: CarStatus) {
        maxRPM = s.maxRPM
        idleRPM = s.idleRPM
        maxGears = s.maxGears
        pitLimiterOn = s.pitLimiterOn
    }

    mutating func apply(_ t: CarTelemetry2) {
        aeroStraightMode = t.aeroMode == .straight
        aeroAvailable = t.aeroAvailable
        overtakeAvailable = t.overtakeAvailable
        overtakeActive = t.overtakeActive
        is2026Regulations = t.is2026Regulations
    }
}
