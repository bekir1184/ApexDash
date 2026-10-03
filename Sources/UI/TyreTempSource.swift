import SwiftUI

/// Which tyre temperature a dashboard shows as its big number.
///
/// The games report two: the surface, which reacts within a corner, and the
/// core (carcass), which decides grip over a stint. Drivers disagree about
/// which one belongs in the corner of their eye, so they choose; the layouts
/// stay as they are and only the value in them changes.
///
/// Stored in settings as `tyreTemp`. Surface is the default, so nothing moves
/// for anyone who never opens the setting.
enum TyreTempSource: String, CaseIterable {
    case surface, core

    static func resolve(_ stored: String) -> TyreTempSource {
        TyreTempSource(rawValue: stored) ?? .surface
    }

    /// The temperatures shown large.
    func primary(_ dash: DashboardModel) -> [Int] {
        self == .core ? dash.tyreInnerTemps : dash.tyreSurfaceTemps
    }

    /// The temperatures shown small, on the dashboards that have room for both.
    func secondary(_ dash: DashboardModel) -> [Int] {
        self == .core ? dash.tyreSurfaceTemps : dash.tyreInnerTemps
    }
}

private struct TyreTempSourceKey: EnvironmentKey {
    static let defaultValue = TyreTempSource.surface
}

extension EnvironmentValues {
    /// Set once by `RootDashboardView`, read by every dashboard.
    var tyreTempSource: TyreTempSource {
        get { self[TyreTempSourceKey.self] }
        set { self[TyreTempSourceKey.self] = newValue }
    }
}
