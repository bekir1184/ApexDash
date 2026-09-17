import SwiftUI

/// The dot matrix texture of real wheel LCDs: a regular grid of dots is punched through the
/// content, so every shape breaks into pixels. Unlit dots are not drawn here;
/// `DotGridBackground` spreads them across the whole screen, so the panel and its edges
/// share the same brightness.
struct DotMatrixEffect: ViewModifier {
    var pitch: CGFloat = 5
    /// Share of each cell covered by its dot. Higher values make a brighter panel.
    var dotRatio: CGFloat = 0.8

    func body(content: Content) -> some View {
        dotted(content)
            // The slight bleed of real LED panels: a blurred copy of the dotted layer
            // underneath adds glow.
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

/// Background of unlit LEDs. The content stays in the safe area, but the texture covers the
/// whole screen, including under the Dynamic Island.
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
