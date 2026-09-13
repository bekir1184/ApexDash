import SwiftUI

/// Uygulama arayuzunun rengi. Panolarin kendi renkleri (sicaklik olcekleri,
/// bayraklar, sektor renkleri) bunun disinda kalir; oralarda renk bilgi
/// tasir, burada kimlik tasir.
enum Palette {
    /// Neredeyse siyah lacivert zemin.
    static let ground = Color(red: 0.082, green: 0.082, blue: 0.118)
    /// Zeminden bir ton acik; kart, rozet ve panel arkasi.
    static let deep = Color(red: 0.137, green: 0.137, blue: 0.180)
    /// Kirmizi: vurgu, secili durum, birincil dugme.
    static let accent = Color(red: 0.882, green: 0.024, blue: 0.0)
    /// Uyari da ayni kirmizi; paletin tek vurgu rengi var.
    static let alert = Color(red: 0.882, green: 0.024, blue: 0.0)
    /// Vurgunun uzerindeki yazi.
    static let onAccent = Color.white
    /// Bagliyken yanan yesil nokta; kirmiziyla karismasin diye korunur.
    static let live = Color(red: 0.24, green: 0.92, blue: 0.35)
    static let ink = Color.white
}
