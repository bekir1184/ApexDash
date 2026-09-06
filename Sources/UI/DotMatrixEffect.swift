import SwiftUI

/// Gercek direksiyon LCD'lerindeki nokta-matris dokusu: icerigin uzerine
/// duzenli bir nokta izgarasi delinir, boylece her sekil piksellere ayrilir.
struct DotMatrixEffect: ViewModifier {
    var pitch: CGFloat = 5
    var dotRatio: CGFloat = 0.62

    func body(content: Content) -> some View {
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
            // Sonmus LED'lerin hafif parıltısı: panel karanlikken bile matris dokusu görünür.
            .overlay {
                Canvas { context, size in
                    let dot = pitch * dotRatio
                    var y: CGFloat = 0
                    while y < size.height {
                        var x: CGFloat = 0
                        while x < size.width {
                            context.fill(Path(CGRect(x: x + (pitch - dot), y: y + (pitch - dot),
                                                     width: dot, height: dot)),
                                         with: .color(.white.opacity(0.05)))
                            x += pitch
                        }
                        y += pitch
                    }
                }
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            }
    }
}

extension View {
    func dotMatrix(pitch: CGFloat = 5) -> some View {
        modifier(DotMatrixEffect(pitch: pitch))
    }
}
