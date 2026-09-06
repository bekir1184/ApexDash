import SwiftUI

/// Ekran duzeni secenekleri. Kullanici ekrana dokunup degistirir, secim saklanir.
enum DashTheme: String, CaseIterable, Identifiable {
    case modern
    case dotMatrix
    case game

    var id: String { rawValue }

    var title: String {
        switch self {
        case .modern: return "MODERN"
        case .dotMatrix: return "DOT MATRIX"
        case .game: return "OYUN"
        }
    }

    var next: DashTheme {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }
}

/// Sicaklik degerlerini renge cevirir. Esikler F1 oyunlarindaki calisma
/// araliklarina gore secildi.
enum TempScale {
    static let cold = Color(red: 0.29, green: 0.62, blue: 1.0)
    static let cool = Color(red: 0.25, green: 0.85, blue: 0.95)
    static let optimal = Color(red: 0.22, green: 0.92, blue: 0.38)
    static let warm = Color(red: 1.0, green: 0.72, blue: 0.11)
    static let hot = Color(red: 1.0, green: 0.24, blue: 0.20)

    /// Lastik yuzey sicakligi (C)
    static func tyre(_ celsius: Int) -> Color {
        switch celsius {
        case ..<70: return cold
        case 70..<85: return cool
        case 85..<110: return optimal
        case 110..<125: return warm
        default: return hot
        }
    }

    /// Fren diski sicakligi (C)
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
