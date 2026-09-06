import SwiftUI

/// Veri gelmeden once gosterilen ekran: pistteki baslangic isiklari gibi
/// soldan saga yanar, hepsi yandiktan sonra soner ve bastan baslar.
/// Altinda oyunda yapilmasi gereken ayarlar durur.
struct WaitingView: View {
    let title: String
    let strings: Strings
    let localIP: String
    let port: UInt16
    let unit: CGFloat

    /// Bes kolon yanar (5 sn), hepsi bir sure yanik kalir, sonra soner.
    private let cycle: Double = 7.5

    var body: some View {
        VStack(spacing: unit * 0.5) {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                let phase = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: cycle)
                lights(litColumns: litColumns(phase: phase))
            }

            Text(title)
                .font(.system(size: unit * 0.5, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .tracking(2)

            settingsNote
        }
        .padding(unit * 0.6)
        .background(.black.opacity(0.96), in: RoundedRectangle(cornerRadius: unit * 0.3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.3, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    /// 0-5 sn arasi her saniye bir kolon; 5-6.5 hepsi yanik; sonrasi sonuk.
    private func litColumns(phase: Double) -> Int {
        switch phase {
        case ..<5: return Int(phase) + 1
        case ..<6.5: return 5
        default: return 0
        }
    }

    private func lights(litColumns: Int) -> some View {
        HStack(spacing: unit * 0.18) {
            ForEach(0..<5, id: \.self) { column in
                VStack(spacing: unit * 0.1) {
                    ForEach(0..<4, id: \.self) { row in
                        // Gercek prosedurdeki gibi alt iki lamba kirmizi yanar.
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

    private var settingsNote: some View {
        VStack(alignment: .leading, spacing: unit * 0.08) {
            Text(verbatim: strings.settingsPath)
                .foregroundStyle(.white.opacity(0.85))
            HStack(alignment: .top, spacing: unit * 0.8) {
                VStack(alignment: .leading, spacing: unit * 0.06) {
                    Text(verbatim: "UDP Telemetry: On")
                    Text(verbatim: "UDP Broadcast Mode: Off")
                    Text(verbatim: "UDP Format: 2026")
                }
                VStack(alignment: .leading, spacing: unit * 0.06) {
                    Text(verbatim: "UDP IP Address: \(localIP)")
                    Text(verbatim: "UDP Port: \(port)")
                    Text(verbatim: "UDP Send Rate: 60 Hz")
                }
            }
            .foregroundStyle(.white.opacity(0.6))

            Text(verbatim: strings.themeHint)
                .foregroundStyle(.white.opacity(0.32))
                .padding(.top, unit * 0.06)
        }
        .font(.system(size: unit * 0.28, weight: .semibold, design: .monospaced))
    }
}
