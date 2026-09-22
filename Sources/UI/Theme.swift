import SwiftUI

/// Dashboard layouts. The player picks one in the menu; the choice is saved.
enum DashTheme: String, CaseIterable, Identifiable {
    case modern
    case dotMatrix
    case realistic
    case broadcast
    case game
    case cluster

    var id: String { rawValue }

    /// Background colour covering the whole screen, so the panel looks edge to edge while
    /// content stays in the safe area.
    var background: Color {
        switch self {
        case .game: return Color(red: 0.11, green: 0.14, blue: 0.18)
        // The cluster's black glass.
        case .cluster: return Color(red: 0.015, green: 0.015, blue: 0.017)
        case .broadcast: return Color(red: 0.02, green: 0.05, blue: 0.09)
        case .modern, .dotMatrix, .realistic: return .black
        }
    }

    var next: DashTheme {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    var previous: DashTheme {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + all.count - 1) % all.count]
    }
}

/// Turns temperatures into colours. Thresholds follow the working ranges in the F1 games.
enum TempScale {
    static let cold = Color(red: 0.29, green: 0.62, blue: 1.0)
    static let cool = Color(red: 0.25, green: 0.85, blue: 0.95)
    static let optimal = Color(red: 0.22, green: 0.92, blue: 0.38)
    static let warm = Color(red: 1.0, green: 0.72, blue: 0.11)
    static let hot = Color(red: 1.0, green: 0.24, blue: 0.20)

    /// Tyre surface temperature (C)
    static func tyre(_ celsius: Int) -> Color {
        switch celsius {
        case ..<70: return cold
        case 70..<85: return cool
        case 85..<110: return optimal
        case 110..<125: return warm
        default: return hot
        }
    }

    /// Brake disc temperature (C)
    static func brake(_ celsius: Int) -> Color {
        switch celsius {
        case ..<200: return cold
        case 200..<350: return cool
        case 350..<700: return optimal
        case 700..<900: return warm
        default: return hot
        }
    }
}
