import SwiftUI

/// The warning shown before first use: the shift warning flashes the screen, and optionally
/// the phone's flash, rapidly. It matters for people with photosensitive epilepsy, so it
/// never closes by itself; it has to be read and confirmed.
struct FlashWarningView: View {
    let strings: Strings
    let unit: CGFloat
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: unit * 0.3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(Typeface.font(unit * 0.9, .black))
                .foregroundStyle(Palette.alert)

            Text(strings.flashWarningTitle)
                .font(Typeface.font(unit * 0.42, .black))
                .foregroundStyle(.white)
                .tracking(2)

            Text(verbatim: strings.flashWarningBody)
                .font(Typeface.font(unit * 0.28, .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: unit * 14)

            Button(action: onDismiss) {
                Text(strings.flashWarningAccept)
                    .font(Typeface.font(unit * 0.28, .black))
                    .tracking(unit * 0.04)
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, unit * 0.7)
                    .padding(.vertical, unit * 0.2)
                    .background(Capsule().fill(Palette.accent))
            }
            .buttonStyle(PressScaleStyle())
            .padding(.top, unit * 0.15)
        }
        .padding(unit * 0.8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
