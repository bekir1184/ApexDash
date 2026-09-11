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

    var lapsTitle: String { pick("TURLAR", "LAPS") }
    var noLaps: String {
        pick("Henuz tamamlanmis tur yok.", "No completed laps yet.")
    }
    var scanQR: String { pick("QR OKUT", "SCAN QR") }
    var scanHint: String {
        pick("Laptopta f1dash-app.vercel.app adresini ac ve oradaki QR'i okut.",
             "Open f1dash-app.vercel.app on your laptop and scan the QR there.")
    }
    func connectedTo(_ code: String) -> String {
        pick("SITEYE BAGLI · \(code)", "CONNECTED · \(code)")
    }
    var disconnect: String { pick("BAGLANTIYI KES", "DISCONNECT") }
    var sendNow: String { pick("SIMDI GONDER", "SEND NOW") }
    func lastSent(_ time: String) -> String {
        pick("son gonderim \(time)", "last sent \(time)")
    }
    var cameraDenied: String {
        pick("Kamera izni yok. Ayarlar › F1Dash'ten acabilirsin.",
             "No camera access. Enable it in Settings › F1Dash.")
    }

    var shareCSV: String { pick("CSV PAYLAS", "SHARE CSV") }
    var scanForWeb: String {
        pick("Turlari sitede gormek icin okut", "Scan to open these laps on the web")
    }
    var close: String { pick("KAPAT", "CLOSE") }
    var lapsButton: String { pick("TURLAR", "LAPS") }

    func addressChanged(from old: String, to new: String) -> String {
        pick("IP DEGISTI: \(old) → \(new). Oyundaki adresi guncelle.",
             "IP CHANGED: \(old) → \(new). Update the address in the game.")
    }

    var setupTitle: String { pick("BAĞLANTI", "CONNECTION") }
    var settingsTitle: String { pick("AYARLAR", "SETTINGS") }
    var settingsButton: String { pick("AYARLAR", "SETTINGS") }
    var connectionTitle: String { pick("BAĞLANTI", "CONNECTION") }
    var connectionSubtitle: String { pick("IP adresi, port ve oyun ayarları", "IP address, port and game settings") }
    var languageTitle: String { pick("DİL", "LANGUAGE") }
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
    var setupButton: String { pick("BAĞLANTI", "CONNECTION") }
    var selectButton: String { pick("SEÇ", "SELECT") }
    var torchToggle: String { pick("VITES UYARISINDA FLAS", "FLASH ON SHIFT WARNING") }
    var torchNote: String {
        pick("Devir sinira dayaninca ekranla birlikte telefonun flasi da yanip soner.",
             "When revs hit the limit the phone's flash blinks in sync with the screen.")
    }
    var menuButton: String { pick("MENÜ", "MENU") }
    var connected: String { pick("BAĞLI", "CONNECTED") }
    var notConnected: String { pick("BAĞLANTI YOK", "NOT CONNECTED") }


    func themeTitle(_ theme: DashTheme) -> String {
        switch theme {
        case .modern: return "MODERN"
        case .dotMatrix: return "DOT MATRIX"
        case .realistic: return "REALISTIC"
        case .broadcast: return pick("YAYIN", "BROADCAST")
        case .game: return pick("OYUN", "GAME")
        }
    }
}
