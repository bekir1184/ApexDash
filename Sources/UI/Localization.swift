import SwiftUI

/// Uygulama dili. Ekrana dokununca cikan cubuktan degistirilir ve saklanir.
enum AppLanguage: String, CaseIterable, Identifiable {
    case turkish = "tr"
    case english = "en"

    var id: String { rawValue }
    var label: String { self == .turkish ? "TR" : "EN" }
    var next: AppLanguage { self == .turkish ? .english : .turkish }
}

/// Ekranda gecen az sayidaki cumle icin basit bir metin tablosu.
/// Gostergelerin kendi etiketleri (KPH, FUEL, LAP...) her iki dilde de ayni
/// kaldigi icin burada yer almiyor.
struct Strings {
    let language: AppLanguage

    private func pick(_ turkish: String, _ english: String) -> String {
        language == .turkish ? turkish : english
    }

    var connectionOff: String { pick("BAGLANTI KAPALI", "NOT LISTENING") }
    var waitingForData: String { pick("VERI BEKLENIYOR", "WAITING FOR DATA") }
    func failure(_ message: String) -> String { pick("HATA: \(message)", "ERROR: \(message)") }

    var settingsPath: String { pick("Oyunda: Ayarlar › Telemetri", "In game: Settings › Telemetry") }
    var themeHint: String {
        pick("Tasarimi degistirmek icin ekrana dokun veya yana kaydir",
             "Tap the screen or swipe sideways to change the layout")
    }
    var tyreInner: String { pick("iç", "in") }

    func themeTitle(_ theme: DashTheme) -> String {
        switch theme {
        case .modern: return "MODERN"
        case .dotMatrix: return "DOT MATRIX"
        case .realistic: return "REALISTIC"
        case .game: return pick("OYUN", "GAME")
        }
    }
}
