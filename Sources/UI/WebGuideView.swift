import SwiftUI

/// Turlarin laptopta nasil izlenecegini anlatan sayfa: hangi adres acilir,
/// QR nasil okutulur, sonra ne olur. Ayarlardan acilir.
struct WebGuideView: View {
    let strings: Strings
    let unit: CGFloat
    let sessionID: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: unit * 0.3) {
            HStack {
                Text(strings.webGuideTitle)
                    .font(Typeface.font(unit * 0.5, .black))
                    .foregroundStyle(.white)
                    .tracking(4)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(Typeface.font(unit * 0.34, .black))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(unit * 0.2)
                }
                .buttonStyle(PressScaleStyle())
            }

            Text(verbatim: strings.webGuideIntro)
                .font(Typeface.font(unit * 0.28, .medium))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            // Adres, bir bakista okunacak kadar buyuk.
            HStack(spacing: unit * 0.25) {
                Image(systemName: "safari")
                    .font(Typeface.font(unit * 0.5, .bold))
                    .foregroundStyle(Palette.accent)
                Text(verbatim: LapExport.siteHost)
                    .font(Typeface.font(unit * 0.52, .black))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(.horizontal, unit * 0.4)
            .padding(.vertical, unit * 0.22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
                .fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
                .stroke(Palette.accent.opacity(0.5), lineWidth: 1.5))

            HStack(alignment: .top, spacing: unit * 0.4) {
                step(1, strings.webGuideStep1)
                step(2, strings.webGuideStep2)
                step(3, strings.webGuideStep3)
            }

            HStack(spacing: unit * 0.2) {
                Image(systemName: sessionID.isEmpty ? "link.badge.plus" : "checkmark.circle.fill")
                    .foregroundStyle(sessionID.isEmpty ? .white.opacity(0.4) : Palette.live)
                Text(verbatim: sessionID.isEmpty ? strings.webGuideNotPaired
                                                 : strings.connectedTo(sessionID))
                    .foregroundStyle(sessionID.isEmpty ? .white.opacity(0.4) : Palette.live)
            }
            .font(Typeface.font(unit * 0.26, .heavy))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, unit * 0.7)
        .padding(.vertical, unit * 0.45)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StripedBackground())
    }

    private func step(_ number: Int, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: unit * 0.12) {
            Text(verbatim: "\(number)")
                .font(Typeface.font(unit * 0.3, .black))
                .foregroundStyle(Palette.onAccent)
                .frame(width: unit * 0.56, height: unit * 0.56)
                .background(Circle().fill(Palette.accent))
            Text(verbatim: text)
                .font(Typeface.font(unit * 0.26, .medium))
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(unit * 0.3)
        .background(RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
            .fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
            .stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}
