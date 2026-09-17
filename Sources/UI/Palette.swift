import SwiftUI

/// The colours of the app's interface. The dashboards' own colours (temperature scales,
/// flags, sector colours) are separate: there colour carries information, here it carries
/// identity.
enum Palette {
    /// Near-black navy background.
    static let ground = Color(red: 0.082, green: 0.082, blue: 0.118)
    /// One step lighter than the background; behind cards, badges and panels.
    static let deep = Color(red: 0.137, green: 0.137, blue: 0.180)
    /// Red: accent, selection, primary button.
    static let accent = Color(red: 0.882, green: 0.024, blue: 0.0)
    /// Warnings use the same red; the palette has a single accent.
    static let alert = Color(red: 0.882, green: 0.024, blue: 0.0)
    /// Text on the accent colour.
    static let onAccent = Color.white
    /// The green dot shown while connected; kept distinct from red.
    static let live = Color(red: 0.24, green: 0.92, blue: 0.35)
    static let ink = Color.white
    /// The slanted background stripes: two neighbouring greys, a touch apart.
    static let stripeNear = Color(red: 0.160, green: 0.160, blue: 0.200)
    static let stripeFar = Color(red: 0.192, green: 0.192, blue: 0.231)
}

/// The app background: dark navy with two slanted grey stripes. The stripes cross the whole
/// screen, with low contrast so they never break up the content above them.
struct StripedBackground: View {
    /// How far the stripes lean from vertical.
    var lean: CGFloat = 0.42
    /// Stripe width as a fraction of the screen width.
    var width: CGFloat = 0.17
    /// Where the first stripe's left edge sits on screen.
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

    /// A parallelogram whose top is shifted right, leaning left as it goes down.
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
