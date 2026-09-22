import SwiftUI

/// Race start lights. They cycle on their own while waiting, and follow the game's light
/// count at a race start.
struct StartLightsView: View {
    /// Number of lit columns (0-5).
    let litColumns: Int
    let unit: CGFloat

    var body: some View {
        HStack(spacing: unit * 0.18) {
            ForEach(0..<5, id: \.self) { column in
                VStack(spacing: unit * 0.1) {
                    ForEach(0..<4, id: \.self) { row in
                        // As in the real procedure, the bottom two lamps light red.
                        lamp(lit: row >= 2 && column < litColumns)
                    }
                }
                .padding(unit * 0.12)
                .background(
                    RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                        .fill(Color(white: 0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
        }
    }

    private func lamp(lit: Bool) -> some View {
        let red = Color(red: 0.95, green: 0.13, blue: 0.1)
        return Circle()
            .fill(lit ? red : Color(white: 0.1))
            .overlay(Circle().stroke(Color.black.opacity(0.7), lineWidth: unit * 0.03))
            .frame(width: unit * 0.46, height: unit * 0.46)
            .shadow(color: lit ? red.opacity(0.9) : .clear, radius: unit * 0.2)
    }
}
