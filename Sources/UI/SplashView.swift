import SwiftUI

/// Vites isiklari ve APEXDASH yazisi; acilis ekrani ve tanitim ortak kullanir.
struct SplashLogo: View {
    let unit: CGFloat

    var body: some View {
        VStack(spacing: unit * 0.42) {
            ShiftBars(lit: 5, barWidth: unit * 0.3, barHeight: unit * 1.0, spacing: unit * 0.17)
            HStack(spacing: 0) {
                Text(verbatim: "APEX").foregroundStyle(.white)
                Text(verbatim: "DASH").foregroundStyle(Palette.accent)
            }
            .font(Typeface.font(unit * 0.95, .black))
            .tracking(unit * 0.07)
        }
    }
}

/// Her acilista kisa acilis ekrani. Sistemin siyah acilis zemininden devam
/// eder: logo belirir, kisa bir an durur, sonra hafifce buyuyerek kaybolur.
struct SplashView: View {
    let unit: CGFloat
    let onDone: () -> Void

    @State private var shown = false
    @State private var leaving = false

    var body: some View {
        ZStack {
            Color.black.opacity(leaving ? 0 : 1)
            SplashLogo(unit: unit)
                .scaleEffect(leaving ? 1.08 : shown ? 1 : 0.94)
                .opacity(shown && !leaving ? 1 : 0)
                .blur(radius: leaving ? 8 : 0)
        }
        .ignoresSafeArea()
        .allowsHitTesting(!leaving)
        .task {
            withAnimation(.easeOut(duration: 0.5)) { shown = true }
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(.easeIn(duration: 0.4)) {
                leaving = true
            } completion: {
                onDone()
            }
        }
    }
}
