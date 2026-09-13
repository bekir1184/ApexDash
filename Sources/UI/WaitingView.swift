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
    /// Ag degisiminde IP degistiyse eski adres; yoksa nil.
    let previousIP: String?
    let onOpenSetup: () -> Void

    /// Bes kolon yanar (5 sn), hepsi bir sure yanik kalir, sonra soner.
    private let cycle: Double = 7.5

    var body: some View {
        VStack(spacing: unit * 0.5) {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                let phase = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: cycle)
                StartLightsView(litColumns: litColumns(phase: phase), unit: unit)
            }

            if let previousIP {
                Text(verbatim: strings.addressChanged(from: previousIP, to: localIP))
                    .font(.system(size: unit * 0.26, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, unit * 0.3)
                    .padding(.vertical, unit * 0.12)
                    .background(Capsule().fill(Palette.accent))
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

            HStack(spacing: unit * 0.3) {
                Button(action: onOpenSetup) {
                    Text(strings.setupButton)
                        .font(.system(size: unit * 0.26, weight: .black, design: .monospaced))
                        .foregroundStyle(Palette.onAccent)
                        .padding(.horizontal, unit * 0.3)
                        .padding(.vertical, unit * 0.12)
                        .background(Capsule().fill(Palette.accent))
                }
                .buttonStyle(.plain)

                Text(verbatim: strings.themeHint)
                    .foregroundStyle(.white.opacity(0.32))
            }
            .padding(.top, unit * 0.12)
        }
        .font(.system(size: unit * 0.28, weight: .semibold, design: .monospaced))
    }
}
