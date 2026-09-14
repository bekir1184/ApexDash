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

/// Kullanicinin dil tercihi. Varsayilan "otomatik": telefonun dili neyse o.
/// Bir dil secilirse telefon dili degisse de o dilde kalir; otomatike
/// donunce yeniden telefonu izler.
enum LanguagePreference: String, CaseIterable, Identifiable {
    case automatic = ""
    case turkish = "tr"
    case english = "en"

    var id: String { rawValue }

    var resolved: AppLanguage {
        switch self {
        case .automatic: return .systemDefault
        case .turkish: return .turkish
        case .english: return .english
        }
    }

    func label(_ strings: Strings) -> String {
        switch self {
        case .automatic: return strings.automaticLanguage
        case .turkish: return "TR"
        case .english: return "EN"
        }
    }
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
        pick("Laptopta www.apexdash.pro adresini ac ve oradaki QR'i okut.",
             "Open www.apexdash.pro on your laptop and scan the QR there.")
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
        pick("Kamera izni yok. Ayarlar › Apex Dash'ten acabilirsin.",
             "No camera access. Enable it in Settings › Apex Dash.")
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
    var webGuideTitle: String { pick("TELEMETRİ SİTESİ", "TELEMETRY SITE") }
    var webGuideSubtitle: String {
        pick("Turlarını laptopta aç ve incele", "Open and study your laps on a laptop")
    }
    var webGuideIntro: String {
        pick("Her turun tam telemetrisi laptobundaki sayfaya kendiliğinden gider: pist haritası, hız, gaz, fren, direksiyon, ERS ve viraj viraj karşılaştırma.",
             "Every lap uploads itself to the page on your laptop: track map, speed, throttle, brake, steering, ERS, and a corner by corner comparison.")
    }
    var webGuideStep1: String {
        pick("Laptopta tarayıcıyı aç ve bu adrese git. Sayfa bir kod ve QR gösterir.",
             "Open a browser on your laptop and go to this address. The page shows a code and a QR.")
    }
    var webGuideStep2: String {
        pick("Aşağıdaki QR OKUT'a bas ve telefonu laptoptaki QR koduna tut.",
             "Tap SCAN QR below and point the phone at the QR code on the laptop.")
    }
    var webGuideStep3: String {
        pick("Hazır. Her tur bitişinde o turun izi sayfaya düşer; sayfayı açık bırakman yeter.",
             "Done. Each finished lap lands on the page by itself; just leave it open.")
    }
    var webGuideNotPaired: String { pick("Henüz eşleşmedi", "Not paired yet") }
    var copyLink: String { pick("KOPYALA", "COPY") }
    var copied: String { pick("KOPYALANDI", "COPIED") }
    var pairInSettings: String {
        pick("Siteye bağlanmak için AYARLAR › TELEMETRİ SİTESİ sayfasını aç.",
             "To connect the site, open SETTINGS › TELEMETRY SITE.")
    }
    var automaticLanguage: String { pick("OTO", "AUTO") }
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
    var flashWarningTitle: String { pick("IŞIK UYARISI", "FLASHING LIGHTS") }
    var flashWarningBody: String {
        pick("Vites zamanı geldiğinde ekran hızla yanıp söner ve ayarlardan açılırsa telefonun flaşı da kullanılır. Işığa duyarlı epilepsiniz varsa bu uyarıları kapalı tutun.",
             "The screen flashes rapidly at the shift point, and the phone's flash can be used too if you enable it. If you have photosensitive epilepsy, keep these warnings off.")
    }
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
        case .cluster: return pick("GÖSTERGE", "CLUSTER")
        }
    }
}
