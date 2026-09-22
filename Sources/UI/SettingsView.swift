import SwiftUI

/// Settings: connection, telemetry site, demo drive, language, shift flash
/// and links to the project.
struct SettingsView: View {
    @Binding var languageID: String
    @AppStorage("shiftTorch") private var shiftTorch = false
    @Environment(\.openURL) private var openURL
    let strings: Strings
    let unit: CGFloat
    let isDemoRunning: Bool
    let onDemo: (Bool) -> Void
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

            ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: unit * 0.3) {
            // Connection
            Button(action: onOpenConnection) {
                row(title: strings.connectionTitle, subtitle: strings.connectionSubtitle) {
                    Image(systemName: "chevron.right")
                        .font(Typeface.font(unit * 0.3, .black))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .buttonStyle(PressScaleStyle())

            // Telemetry site
            Button(action: onOpenWebGuide) {
                row(title: strings.webGuideTitle, subtitle: strings.webGuideSubtitle) {
                    Image(systemName: "chevron.right")
                        .font(Typeface.font(unit * 0.3, .black))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .buttonStyle(PressScaleStyle())

            // Demo drive
            row(title: strings.demoTitle, subtitle: strings.demoSubtitle) {
                Toggle("", isOn: Binding(get: { isDemoRunning }, set: onDemo)).labelsHidden().tint(accent)
            }

            // Language
            row(title: strings.languageTitle, subtitle: nil) {
                HStack(spacing: 0) {
                    // "" follows the phone; the rest come from the String Catalog.
                    ForEach([""] + AppLanguage.available.map(\.code), id: \.self) { option in
                        let on = option == languageID
                        Button { languageID = option } label: {
                            Text(verbatim: option.isEmpty ? strings.automaticLanguage : option.uppercased())
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

            // Shift flash
            row(title: strings.torchToggle, subtitle: strings.torchNote) {
                Toggle("", isOn: $shiftTorch).labelsHidden().tint(accent)
            }

            // Project: open source links
            row(title: strings.projectTitle, subtitle: strings.projectSubtitle) {
                HStack(spacing: unit * 0.2) {
                    linkButton(strings.starOnGitHub, systemImage: "star.fill", url: AppLinks.repository)
                    if let review = AppLinks.writeReview {
                        linkButton(strings.rateApp, systemImage: "heart.fill", url: review)
                    }
                }
            }
            }
            .padding(.bottom, unit * 0.3)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.horizontal, unit * 0.7)
        .padding(.vertical, unit * 0.45)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StripedBackground())
    }

    private func linkButton(_ title: String, systemImage: String, url: URL) -> some View {
        Button { openURL(url) } label: {
            Label(title, systemImage: systemImage)
                .font(Typeface.font(unit * 0.22, .black))
                .foregroundStyle(.white)
                .padding(.horizontal, unit * 0.26)
                .padding(.vertical, unit * 0.12)
                .background(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1.5))
        }
        .buttonStyle(PressScaleStyle())
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
