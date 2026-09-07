import SwiftUI

/// Uygulama dili. Ekrana dokununca cikan cubuktan degistirilir ve saklanir.
enum AppLanguage: String, CaseIterable, Identifiable {
    case turkish = "tr"
    case english = "en"

    var id: String { rawValue }

    /// Telefonun dili Turkce degilse uygulama Ingilizce baslar.
    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return preferred.hasPrefix("tr") ? .turkish : .english
    }
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

    var setupTitle: String { pick("KURULUM", "SETUP") }
    var setupIntro: String {
        pick("Oyun telemetriyi bu telefona gonderecek. Asagidaki degerleri oyunda birebir gir.",
             "The game sends telemetry to this phone. Enter these values in the game exactly.")
    }
    var portLabel: String { pick("DINLENEN PORT", "LISTENING PORT") }
    var phoneAddress: String { pick("BU TELEFONUN IP ADRESI", "THIS PHONE'S IP ADDRESS") }
    var gameSettings: String { pick("OYUNDA: AYARLAR › TELEMETRI", "IN GAME: SETTINGS › TELEMETRY") }
    var broadcastNote: String {
        pick("Broadcast kapali kalmali: iOS yayin trafigini ancak Apple onayli bir yetkiyle alabilir.",
             "Broadcast must stay off: iOS only receives broadcast traffic with an Apple-approved entitlement.")
    }
    var startButton: String { pick("BASLA", "START") }
    var setupButton: String { pick("KURULUMU AC", "OPEN SETUP") }
    var copied: String { pick("KOPYALANDI", "COPIED") }
    var copy: String { pick("KOPYALA", "COPY") }

    func themeTitle(_ theme: DashTheme) -> String {
        switch theme {
        case .modern: return "MODERN"
        case .dotMatrix: return "DOT MATRIX"
        case .realistic: return "REALISTIC"
        case .game: return pick("OYUN", "GAME")
        }
    }
}
