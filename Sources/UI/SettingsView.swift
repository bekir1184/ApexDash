import SwiftUI

/// Ayarlar: baglanti (IP / port), dil ve vites uyarisinda flas.
struct SettingsView: View {
    @Binding var languageID: String
    @AppStorage("shiftTorch") private var shiftTorch = false
    let strings: Strings
    let unit: CGFloat
    let onOpenConnection: () -> Void
    let onOpenWebGuide: () -> Void
    let onClose: () -> Void

    private let accent = Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: unit * 0.3) {
            HStack {
                Text(strings.settingsTitle)
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

            // Baglanti
            Button(action: onOpenConnection) {
                row(title: strings.connectionTitle, subtitle: strings.connectionSubtitle) {
                    Image(systemName: "chevron.right")
                        .font(Typeface.font(unit * 0.3, .black))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .buttonStyle(PressScaleStyle())

            // Telemetri sitesi
            Button(action: onOpenWebGuide) {
                row(title: strings.webGuideTitle, subtitle: strings.webGuideSubtitle) {
                    Image(systemName: "chevron.right")
                        .font(Typeface.font(unit * 0.3, .black))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .buttonStyle(PressScaleStyle())

            // Dil
            row(title: strings.languageTitle, subtitle: nil) {
                HStack(spacing: 0) {
                    ForEach(LanguagePreference.allCases) { option in
                        let on = option.rawValue == languageID
                        Button { languageID = option.rawValue } label: {
                            Text(verbatim: option.label(strings))
                                .font(Typeface.font(unit * 0.26, .black))
                                .foregroundStyle(on ? Palette.onAccent : .white.opacity(0.7))
                                .padding(.horizontal, unit * 0.3)
                                .padding(.vertical, unit * 0.12)
                                .background(Capsule().fill(on ? Palette.accent : Color.clear))
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .padding(unit * 0.05)
                .background(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                .animation(.spring(duration: 0.3), value: languageID)
            }

            // Flas
            row(title: strings.torchToggle, subtitle: strings.torchNote) {
                Toggle("", isOn: $shiftTorch).labelsHidden().tint(accent)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, unit * 0.7)
        .padding(.vertical, unit * 0.45)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StripedBackground())
    }

    private func row<Trailing: View>(title: String, subtitle: String?,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: unit * 0.3) {
            VStack(alignment: .leading, spacing: unit * 0.04) {
                Text(title)
                    .font(Typeface.font(unit * 0.28, .heavy))
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(Typeface.font(unit * 0.22, .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: unit * 0.3)
            trailing()
        }
        .padding(unit * 0.3)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}
