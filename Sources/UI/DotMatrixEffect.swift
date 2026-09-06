import SwiftUI

/// Gercek direksiyon LCD'lerindeki nokta-matris dokusu: icerigin uzerine
/// duzenli bir nokta izgarasi delinir, boylece her sekil piksellere ayrilir.
/// Sonmus noktalar burada cizilmez; onlari `DotGridBackground` ekranin
/// tamamina serer, boylece panelin ici ile kenarlari ayni parlaklikta kalir.
struct DotMatrixEffect: ViewModifier {
    var pitch: CGFloat = 5
    /// Noktanin hucre icinde kapladigi oran. Yuksek deger = daha parlak panel.
    var dotRatio: CGFloat = 0.8

    func body(content: Content) -> some View {
        dotted(content)
            // Gercek LED panellerdeki hafif tasma: noktali katmanin bulanik bir
            // kopyasi altina konarak parlaklik artirilir.
            .background {
                dotted(content)
                    .blur(radius: pitch * 0.9)
                    .brightness(0.06)
            }
    }

    private func dotted(_ content: Content) -> some View {
        content
            .overlay {
                Canvas { context, size in
                    let gap = pitch * (1 - dotRatio)
                    var y: CGFloat = 0
                    while y < size.height {
                        var x: CGFloat = 0
                        while x < size.width {
                            context.fill(Path(CGRect(x: x, y: y, width: gap, height: pitch)),
                                         with: .color(.black))
                            x += pitch
                        }
                        context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: gap)),
                                     with: .color(.black))
                        y += pitch
                    }
                }
                .blendMode(.destinationOut)
                .allowsHitTesting(false)
            }
            .compositingGroup()
    }
}

extension View {
    func dotMatrix(pitch: CGFloat = 5) -> some View {
        modifier(DotMatrixEffect(pitch: pitch))
    }
}

/// Sonmus LED'lerden olusan zemin. Icerik guvenli alanda kalsa da doku
/// ekranin tamamini - Dynamic Island'in altini da - kaplar.
struct DotGridBackground: View {
    var pitch: CGFloat = 5
    var dotRatio: CGFloat = 0.8

    var body: some View {
        Canvas { context, size in
            let dot = pitch * dotRatio
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    context.fill(Path(CGRect(x: x + (pitch - dot), y: y + (pitch - dot),
                                             width: dot, height: dot)),
                                 with: .color(.white.opacity(0.07)))
                    x += pitch
                }
                y += pitch
            }
        }
        .background(Color.black)
    }
}
