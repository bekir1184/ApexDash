import SwiftUI

/// Throttle and brake input: the thin bars of wheel displays.
struct PedalBarsView: View {
    let throttle: Float
    let brake: Float

    var body: some View {
        HStack(spacing: 18) {
            bar(label: "BRK", value: brake, color: Color(red: 1.0, green: 0.19, blue: 0.19), mirrored: true)
            bar(label: "THR", value: throttle, color: Color(red: 0.16, green: 0.9, blue: 0.35), mirrored: false)
        }
    }

    private func bar(label: String, value: Float, color: Color, mirrored: Bool) -> some View {
        HStack(spacing: 10) {
            if mirrored { text(label) }
            GeometryReader { geo in
                ZStack(alignment: mirrored ? .trailing : .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))
                        .shadow(color: color.opacity(0.6), radius: 6)
                }
            }
            .frame(height: 14)
            if !mirrored { text(label) }
        }
    }

    private func text(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white.opacity(0.45))
    }
}
