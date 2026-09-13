import SwiftUI

/// Uygulamanin yazi tipi. Saira (SIL Open Font License 1.1) kullaniliyor:
/// genis ve geometrik, rakamlari bir gostergede bir bakista okunacak kadar
/// net. Formula 1'in kendi yazi tipi tescilli oldugu icin kullanilamaz.
enum Typeface {
    /// Agirliga karsilik gelen kesit adi; kayitli PostScript adlari.
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

    /// Duz yazi.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(name(for: weight), fixedSize: size)
    }

    /// Rakamlari sabit genislikte: degisen sayilar yerinden oynamasin.
    static func digits(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        font(size, weight).monospacedDigit()
    }

    /// UIKit tarafi (QR tarayici gibi) icin ayni kesitler.
    static func uiFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> UIFont {
        UIFont(name: name(for: weight), size: size) ?? .systemFont(ofSize: size, weight: .regular)
    }
}
