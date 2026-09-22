import SwiftUI

/// The 15 LED rev strip of a real wheel. Colours from left to right: 5 green, 5 red, 5 blue
/// (shift point).
struct RevLightsView: View {
    let bits: UInt16
    let flashing: Bool
    @State private var flashOn = false

    private static let colors: [Color] = (0..<15).map { index in
        switch index {
        case 0..<5: return Color(red: 0.13, green: 0.92, blue: 0.31)
        case 5..<10: return Color(red: 1.0, green: 0.16, blue: 0.16)
        default: return Color(red: 0.36, green: 0.44, blue: 1.0)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let spacing = geo.size.width * 0.008
            let width = (geo.size.width - spacing * 14) / 15
            HStack(spacing: spacing) {
                ForEach(0..<15, id: \.self) { index in
                    let lit = isLit(index)
                    RoundedRectangle(cornerRadius: width * 0.18, style: .continuous)
                        .fill(lit ? Self.colors[index] : Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: width * 0.18, style: .continuous)
                                .stroke(Color.white.opacity(lit ? 0.35 : 0.08), lineWidth: 1)
                        )
                        .shadow(color: lit ? Self.colors[index].opacity(0.9) : .clear,
                                radius: width * 0.35)
                }
            }
        }
        .onChange(of: flashing) { _, active in
            if !active { flashOn = false }
        }
        .task(id: flashing) {
            guard flashing else { return }
            while !Task.isCancelled {
                flashOn.toggle()
                try? await Task.sleep(nanoseconds: 60_000_000)
            }
        }
    }

    private func isLit(_ index: Int) -> Bool {
        if flashing { return flashOn }
        return bits & (1 << UInt16(index)) != 0
    }
}
