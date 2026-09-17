import SwiftUI

/// A language the app ships in. The list comes from the translations in
/// `Resources/Localizable.xcstrings`: add a language there and it appears in
/// Settings on its own. See CONTRIBUTING.md.
struct AppLanguage: Hashable, Identifiable {
    /// Language code as used by the String Catalog, for example "en", "tr", "pt-BR".
    let code: String

    var id: String { code }

    /// Short label for the language picker, for example "EN".
    var label: String { code.uppercased() }

    static let english = AppLanguage(code: "en")

    /// Languages with a translation in the app bundle, English first. The bundle
    /// lists a language once per source (folder and Info.plist), so duplicates
    /// are removed here.
    static var available: [AppLanguage] {
        let codes = Set(Bundle.main.localizations.filter { $0 != "Base" })
        return codes.sorted { $0 == "en" ? true : ($1 == "en" ? false : $0 < $1) }.map(AppLanguage.init)
    }

    /// The first of the phone's preferred languages the app supports, else English.
    static var systemDefault: AppLanguage {
        let available = self.available
        for preferred in Locale.preferredLanguages {
            let lower = preferred.lowercased()
            if let exact = available.first(where: { lower.hasPrefix($0.code.lowercased()) }) { return exact }
        }
        return .english
    }

    /// Resolves a stored preference: an empty string means "follow the phone".
    static func resolve(_ preference: String) -> AppLanguage {
        guard !preference.isEmpty,
              let match = available.first(where: { $0.code == preference }) else { return systemDefault }
        return match
    }

    fileprivate var bundle: Bundle {
        Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }
}

/// All user-facing text, looked up in the String Catalog for the chosen
/// language. Dashboard labels such as KPH, FUEL and LAP stay in English, as on
/// real steering wheel displays.
struct Strings {
    let language: AppLanguage
    private let bundle: Bundle
    private let fallback: Bundle

    init(language: AppLanguage) {
        self.language = language
        self.bundle = language.bundle
        self.fallback = AppLanguage.english.bundle
    }

    /// The translation for `key`, with `%1$@`-style placeholders filled in.
    /// Missing translations fall back to English.
    func text(_ key: String, _ arguments: String...) -> String {
        let english = fallback.localizedString(forKey: key, value: key, table: nil)
        let format = bundle.localizedString(forKey: key, value: english, table: nil)
        guard !arguments.isEmpty else { return format }
        return String(format: format, arguments: arguments.map { $0 as NSString })
    }

    var connectionOff: String { text("connectionOff") }
    var demoStart: String { text("demoStart") }
    var demoBadge: String { text("demoBadge") }
    var demoTitle: String { text("demoTitle") }
    var demoSubtitle: String { text("demoSubtitle") }
    var projectTitle: String { text("projectTitle") }
    var projectSubtitle: String { text("projectSubtitle") }
    var starOnGitHub: String { text("starOnGitHub") }
    var rateApp: String { text("rateApp") }
    var waitingForData: String { text("waitingForData") }
    func formatMismatch(_ game: String) -> String { text("formatMismatch", game) }
    func failure(_ message: String) -> String { text("failure", message) }

    var settingsPath: String { text("settingsPath") }
    var themeHint: String { text("themeHint") }
    var tyreInner: String { text("tyreInner") }

    var lapsTitle: String { text("lapsTitle") }
    var noLaps: String { text("noLaps") }
    var scanQR: String { text("scanQR") }
    func connectedTo(_ code: String) -> String { text("connectedTo", code) }
    var disconnect: String { text("disconnect") }
    func lastSent(_ time: String) -> String { text("lastSent", time) }

    var shareCSV: String { text("shareCSV") }
    var lapsButton: String { text("lapsButton") }

    func addressChanged(from old: String, to new: String) -> String { text("addressChanged", old, new) }

    var setupTitle: String { text("setupTitle") }
    var settingsTitle: String { text("settingsTitle") }
    var settingsButton: String { text("settingsButton") }
    var connectionTitle: String { text("connectionTitle") }
    var connectionSubtitle: String { text("connectionSubtitle") }
    var languageTitle: String { text("languageTitle") }
    var webGuideTitle: String { text("webGuideTitle") }
    var webGuideSubtitle: String { text("webGuideSubtitle") }
    var webGuideIntro: String { text("webGuideIntro") }
    var webGuideStep1: String { text("webGuideStep1") }
    var webGuideStep2: String { text("webGuideStep2") }
    func localAnalysisHint(_ address: String) -> String { text("localAnalysisHint", address) }
    var webGuideStep3: String { text("webGuideStep3") }
    func browserConnected(_ address: String) -> String { text("browserConnected", address) }
    var webGuideNotPaired: String { text("webGuideNotPaired") }
    var copyLink: String { text("copyLink") }
    var copied: String { text("copied") }
    var pairInSettings: String { text("pairInSettings") }
    var automaticLanguage: String { text("automaticLanguage") }
    var setupIntro: String { text("setupIntro") }
    var portLabel: String { text("portLabel") }
    var phoneAddress: String { text("phoneAddress") }
    var gameSettings: String { text("gameSettings") }
    var broadcastNote: String { text("broadcastNote") }
    var setupButton: String { text("setupButton") }
    var selectButton: String { text("selectButton") }
    var flashWarningAccept: String { text("flashWarningAccept") }
    var flashWarningTitle: String { text("flashWarningTitle") }
    var flashWarningBody: String { text("flashWarningBody") }
    var torchToggle: String { text("torchToggle") }
    var torchNote: String { text("torchNote") }
    var connected: String { text("connected") }
    var notConnected: String { text("notConnected") }


    func themeTitle(_ theme: DashTheme) -> String {
        switch theme {
        case .modern: return text("themeModern")
        case .dotMatrix: return text("themeDotMatrix")
        case .realistic: return text("themeRealistic")
        case .broadcast: return text("themeBroadcast")
        case .game: return text("themeGame")
        case .cluster: return text("themeCluster")
        }
    }
}
