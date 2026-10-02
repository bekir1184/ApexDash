import SwiftUI

/// Kilometres or miles per hour. Telemetry is always carried in km/h; this only
/// changes what the dashboards and the analysis page show.
///
/// The choice is stored in settings as `speedUnit`. An empty setting follows the
/// phone's region, so a player in the US or the UK sees mph without asking.
enum SpeedUnit: String, CaseIterable {
    case kph, mph

    /// The unit the phone's region drives in.
    static var regional: SpeedUnit {
        switch Locale.current.measurementSystem {
        case .us, .uk: return .mph
        default: return .kph
        }
    }

    /// Turns a stored setting into a unit; anything unknown follows the region.
    static func resolve(_ stored: String) -> SpeedUnit {
        SpeedUnit(rawValue: stored) ?? regional
    }

    /// Converts a speed in km/h for display.
    func value(fromKPH kph: Int) -> Int {
        self == .mph ? Int((Double(kph) * 0.621371).rounded()) : kph
    }

    /// Shown next to the number, as the dashboards set it.
    var label: String { self == .mph ? "MPH" : "KM/H" }

    /// Where a design has room for three letters only, as on the wheel LCDs.
    var compactLabel: String { self == .mph ? "MPH" : "KPH" }

    /// The same label where the design wants lower case.
    var smallLabel: String { self == .mph ? "mph" : "km/h" }
}

private struct SpeedUnitKey: EnvironmentKey {
    static let defaultValue = SpeedUnit.kph
}

extension EnvironmentValues {
    /// Set once by `RootDashboardView`, read by every dashboard.
    var speedUnit: SpeedUnit {
        get { self[SpeedUnitKey.self] }
        set { self[SpeedUnitKey.self] = newValue }
    }
}
