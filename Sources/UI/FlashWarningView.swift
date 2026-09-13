import SwiftUI

/// Ilk acilista bir kez gorunen kisa uyari: vites ikazi ekrani ve istege
/// bagli olarak telefonun flasini hizla yakip sondurur. Isiga duyarli
/// epilepsisi olanlar icin onemli oldugundan, ayar acilmadan once soylenir.
struct FlashWarningView: View {
    let strings: Strings
    let unit: CGFloat
    let onDismiss: () -> Void

    @State private var remaining = 3

    var body: some View {
        VStack(spacing: unit * 0.3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: unit * 0.9, weight: .black))
                .foregroundStyle(Palette.alert)

            Text(strings.flashWarningTitle)
                .font(.system(size: unit * 0.42, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tracking(2)

            Text(verbatim: strings.flashWarningBody)
                .font(.system(size: unit * 0.28, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: unit * 14)

            Text(verbatim: "\(remaining)")
                .font(.system(size: unit * 0.26, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .contentTransition(.numericText(countsDown: true))
        }
        .padding(unit * 0.8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ground.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .task {
            for _ in 0..<3 {
                try? await Task.sleep(for: .seconds(1))
                withAnimation(.spring(duration: 0.25)) { remaining -= 1 }
            }
            onDismiss()
        }
    }
}
