import SwiftUI

/// Shown before data arrives: lights come on from left to right like start lights, go out
/// once all are lit and start again. The game settings to enter sit below.
struct WaitingView: View {
    let title: String
    let strings: Strings
    let localIP: String
    let port: UInt16
    let unit: CGFloat
    /// The old address if the IP changed with the network; otherwise nil.
    let previousIP: String?
    let onOpenSetup: () -> Void

    /// Five columns light up (5 s), stay lit for a moment, then go out.
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
                    .font(Typeface.digits(unit * 0.26, .heavy))
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, unit * 0.3)
                    .padding(.vertical, unit * 0.12)
                    .background(Capsule().fill(Palette.accent))
            }

            Text(title)
                .font(Typeface.digits(unit * 0.5, .black))
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

    /// One column per second from 0-5 s; all lit from 5-6.5 s; dark after that.
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
                        .font(Typeface.digits(unit * 0.26, .black))
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
        .font(Typeface.digits(unit * 0.28, .semibold))
    }
}
