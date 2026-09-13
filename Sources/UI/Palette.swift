import SwiftUI

/// Uygulama arayuzunun rengi: logodan alinan uc renk. Panolarin kendi
/// renkleri (sicaklik olcekleri, bayraklar, sektor renkleri) bunun disinda
/// kalir; oralarda renk bilgi tasir, burada kimlik tasir.
enum Palette {
    /// Lacivert zemin.
    static let ground = Color(red: 0.16, green: 0.16, blue: 0.27)
    /// Zeminden bir ton koyu; kart ve panel arkasi.
    static let deep = Color(red: 0.11, green: 0.11, blue: 0.20)
    /// Sari: vurgu, secili durum, birincil dugme.
    static let accent = Color(red: 1.0, green: 0.98, blue: 0.36)
    /// Kirmizi: uyari ve dikkat.
    static let alert = Color(red: 0.98, green: 0.18, blue: 0.10)
    /// Bagliyken yanan yesil nokta icin; sari ile karismasin diye korunur.
    static let live = Color(red: 0.24, green: 0.92, blue: 0.35)
    static let ink = Color.white
}
