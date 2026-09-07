import SwiftUI

/// Direksiyon uzerindeki yuvarlak dugme.
struct WheelButton: View {
    let title: String
    let caption: String?
    let color: Color
    let unit: CGFloat
    var action: () -> Void

    var body: some View {
        VStack(spacing: unit * 0.06) {
            Button(action: action) {
                Text(verbatim: title)
                    .font(.system(size: unit * 0.34, weight: .black, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.75))
                    .frame(width: unit * 0.78, height: unit * 0.78)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [color, color.opacity(0.55)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    )
                    .overlay(
                        Circle().stroke(
                            LinearGradient(colors: [.white.opacity(0.6), .black.opacity(0.65)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: unit * 0.06
                        )
                    )
                    .shadow(color: .black.opacity(0.7), radius: unit * 0.1, y: unit * 0.04)
            }
            .buttonStyle(.plain)

            if let caption {
                Text(verbatim: caption)
                    .font(.system(size: unit * 0.18, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }
}

/// Direksiyonun alt sirasindaki dondurmeli anahtar. Gorsel; kademesi
/// disaridan verilir.
struct RotaryDial: View {
    let label: String
    let positions: Int
    let value: Int
    let color: Color
    let unit: CGFloat

    var body: some View {
        VStack(spacing: unit * 0.06) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(white: 0.2), Color(white: 0.07)],
                                         startPoint: .top, endPoint: .bottom))
                Circle().stroke(Color.black.opacity(0.8), lineWidth: unit * 0.06)

                ForEach(0..<positions, id: \.self) { index in
                    Capsule()
                        .fill(index == value % positions ? color : Color.white.opacity(0.22))
                        .frame(width: unit * 0.05, height: unit * 0.12)
                        .offset(y: -unit * 0.42)
                        .rotationEffect(.degrees(Double(index) / Double(positions) * 360))
                }

                Capsule()
                    .fill(color)
                    .frame(width: unit * 0.07, height: unit * 0.3)
                    .offset(y: -unit * 0.14)
                    .rotationEffect(.degrees(Double(value % positions) / Double(positions) * 360))

                Circle()
                    .fill(LinearGradient(colors: [Color(white: 0.32), Color(white: 0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: unit * 0.34, height: unit * 0.34)
            }
            .frame(width: unit * 1.15, height: unit * 1.15)

            Text(verbatim: label)
                .font(.system(size: unit * 0.18, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}
