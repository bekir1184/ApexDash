import SwiftUI

/// Ayarlar: baglanti (IP / port), dil ve vites uyarisinda flas.
struct SettingsView: View {
    @Binding var languageID: String
    @AppStorage("shiftTorch") private var shiftTorch = false
    let strings: Strings
    let unit: CGFloat
    let onOpenConnection: () -> Void
    let onClose: () -> Void

    private let accent = Color(red: 0.95, green: 0.85, blue: 0.15)

    var body: some View {
        VStack(alignment: .leading, spacing: unit * 0.3) {
            HStack {
                Text(strings.settingsTitle)
                    .font(.system(size: unit * 0.5, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(4)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: unit * 0.34, weight: .black))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(unit * 0.2)
                }
                .buttonStyle(PressScaleStyle())
            }

            // Baglanti
            Button(action: onOpenConnection) {
                row(title: strings.connectionTitle, subtitle: strings.connectionSubtitle) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: unit * 0.3, weight: .black))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .buttonStyle(PressScaleStyle())

            // Dil
            row(title: strings.languageTitle, subtitle: nil) {
                HStack(spacing: 0) {
                    ForEach(AppLanguage.allCases) { option in
                        let on = option.rawValue == languageID
                        Button { languageID = option.rawValue } label: {
                            Text(verbatim: option.label)
                                .font(.system(size: unit * 0.26, weight: .black, design: .rounded))
                                .foregroundStyle(on ? .black : .white.opacity(0.7))
                                .padding(.horizontal, unit * 0.36)
                                .padding(.vertical, unit * 0.12)
                                .background(Capsule().fill(on ? Color.white : Color.clear))
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
        .background(Color(red: 0.05, green: 0.06, blue: 0.08))
    }

    private func row<Trailing: View>(title: String, subtitle: String?,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: unit * 0.3) {
            VStack(alignment: .leading, spacing: unit * 0.04) {
                Text(title)
                    .font(.system(size: unit * 0.28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(.system(size: unit * 0.22, weight: .semibold, design: .rounded))
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
