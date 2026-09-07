import SwiftUI

/// Direksiyon govdesindeki karbon dokusu: capraz orgu deseni ve kenarlara
/// dogru koyulasan bir vinyet.
struct CarbonBackground: View {
    var pitch: CGFloat = 10

    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.055, blue: 0.06)

            Canvas { context, size in
                let step = pitch
                var y: CGFloat = 0
                var row = 0
                while y < size.height {
                    var x: CGFloat = (row % 2 == 0) ? 0 : step
                    while x < size.width {
                        context.fill(
                            Path(roundedRect: CGRect(x: x, y: y, width: step * 0.9, height: step * 0.9),
                                 cornerRadius: step * 0.2),
                            with: .color(.white.opacity(0.028))
                        )
                        x += step * 2
                    }
                    y += step
                    row += 1
                }
            }

            RadialGradient(colors: [.clear, .black.opacity(0.75)],
                           center: .center, startRadius: 0, endRadius: 700)
        }
    }
}

/// Karbon panellerin kosesindeki perçinler.
struct Rivets: ViewModifier {
    var inset: CGFloat
    var size: CGFloat

    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { geo in
                ForEach(0..<4, id: \.self) { corner in
                    Circle()
                        .fill(
                            LinearGradient(colors: [Color.white.opacity(0.45), Color.black.opacity(0.8)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: size, height: size)
                        .position(x: corner % 2 == 0 ? inset : geo.size.width - inset,
                                  y: corner < 2 ? inset : geo.size.height - inset)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

extension View {
    func rivets(inset: CGFloat, size: CGFloat) -> some View {
        modifier(Rivets(inset: inset, size: size))
    }

    /// Karbon panel: hafif gradyan, pahli kenar ve percinler.
    func carbonPlate(unit: CGFloat) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
                    .fill(LinearGradient(colors: [Color(white: 0.13), Color(white: 0.07)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [Color.white.opacity(0.28), Color.black.opacity(0.7)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: unit * 0.05
                    )
            )
            .rivets(inset: unit * 0.24, size: unit * 0.12)
    }
}
