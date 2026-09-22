import SwiftUI

/// The typeface of the app's chrome: menu, settings, connection, laps and warnings. Saira
/// (SIL Open Font License 1.1) is used, because Formula 1's own typeface is proprietary.
///
/// Dashboards do not use it. Their layouts are measured against the system font: Saira is
/// wider, and numbers and labels overflowed their boxes. Dashboard text stays monospaced,
/// as on real wheel displays.
enum Typeface {
    /// The font face for each weight; registered PostScript names.
    private static func name(for weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light, .regular: return "Saira-Regular"
        case .medium:                              return "Saira-Medium"
        case .semibold:                            return "Saira-SemiBold"
        case .bold:                                return "Saira-Bold"
        case .heavy:                               return "Saira-ExtraBold"
        case .black:                               return "Saira-Black"
        default:                                   return "Saira-Regular"
        }
    }

    /// Plain text.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(name(for: weight), fixedSize: size)
    }

    /// Fixed-width digits, so changing numbers do not jitter.
    static func digits(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        font(size, weight).monospacedDigit()
    }

    /// The same faces for UIKit, such as the QR scanner.
    static func uiFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> UIFont {
        UIFont(name: name(for: weight), size: size) ?? .systemFont(ofSize: size, weight: .regular)
    }
}
