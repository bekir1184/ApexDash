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
    /// Zemindeki egik seritler: iki komsu gri, birbirinden bir tik farkli.
    static let stripeNear = Color(red: 0.160, green: 0.160, blue: 0.200)
    static let stripeFar = Color(red: 0.192, green: 0.192, blue: 0.231)
}

/// Uygulamanin zemini: koyu lacivert ve uzerinde iki egik gri serit.
/// Seritler ekranin tamamini kat eder, ustunde duran icerigi bolmemesi icin
/// kontrasti dusuk tutulur.
struct StripedBackground: View {
    /// Seritlerin dikeyden sapmasi.
    var lean: CGFloat = 0.42
    /// Serit genisligi, ekran genisliginin orani olarak.
    var width: CGFloat = 0.17
    /// Ilk seridin sol kenarinin ekrandaki yeri.
    var start: CGFloat = 0.22

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let band = w * width
            let gap = band * 0.22
            ZStack {
                Palette.ground
                stripe(x: w * start, band: band, height: h, lean: lean)
                    .fill(Palette.stripeNear)
                stripe(x: w * start + band + gap, band: band, height: h, lean: lean)
                    .fill(Palette.stripeFar)
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .ignoresSafeArea()
    }

    /// Tepesi saga kaymis paralelkenar; asagi indikce sola yatar.
    private func stripe(x: CGFloat, band: CGFloat, height: CGFloat, lean: CGFloat) -> Path {
        let shift = height * lean
        var path = Path()
        path.move(to: CGPoint(x: x + shift, y: 0))
        path.addLine(to: CGPoint(x: x + shift + band, y: 0))
        path.addLine(to: CGPoint(x: x + band, y: height))
        path.addLine(to: CGPoint(x: x, y: height))
        path.closeSubpath()
        return path
    }
}
