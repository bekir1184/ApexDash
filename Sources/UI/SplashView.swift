import SwiftUI

/// Acilis animasyonu: bes vites isigi soldan saga hizla yanar, ardindan
/// APEXDASH harfleri sirayla asagidan gelir. Her acilis ve tanitimin
/// basi ayni diziyi kullanir. Bitince `onDone` cagrilir.
struct SplashLogo: View {
    let unit: CGFloat
    var hold: Duration = .milliseconds(900)
    let onDone: () -> Void

    @State private var lit = 0
    @State private var wordmark = false

    private let letters = Array("APEXDASH")

    var body: some View {
        VStack(spacing: unit * 0.42) {
            ShiftBars(lit: lit, barWidth: unit * 0.3, barHeight: unit * 1.0, spacing: unit * 0.17)
            HStack(spacing: unit * 0.07) {
                ForEach(letters.indices, id: \.self) { index in
                    Text(String(letters[index]))
                        .foregroundStyle(index < 4 ? Color.white : Palette.accent)
                        .opacity(wordmark ? 1 : 0)
                        .offset(y: wordmark ? 0 : unit * 0.3)
                        .blur(radius: wordmark ? 0 : 6)
                        .animation(.spring(duration: 0.6, bounce: 0.2).delay(Double(index) * 0.035), value: wordmark)
                }
            }
            .font(Typeface.font(unit * 0.95, .black))
        }
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            for step in 1...5 {
                withAnimation(.spring(duration: 0.2, bounce: 0.35)) { lit = step }
                Haptics.impact(.light, intensity: 0.4 + CGFloat(step) * 0.08)
                try? await Task.sleep(for: .milliseconds(90))
            }
            wordmark = true
            try? await Task.sleep(for: .milliseconds(350))
            try? await Task.sleep(for: hold)
            onDone()
        }
    }
}

/// Her acilista kisa acilis ekrani. Sistemin siyah acilis zemininden devam
/// eder; animasyon bitince hafifce buyuyerek kaybolur.
struct SplashView: View {
    let unit: CGFloat
    let onDone: () -> Void

    @State private var leaving = false

    var body: some View {
        ZStack {
            Color.black.opacity(leaving ? 0 : 1)
            SplashLogo(unit: unit, hold: .milliseconds(650)) {
                withAnimation(.easeIn(duration: 0.4)) {
                    leaving = true
                } completion: {
                    onDone()
                }
            }
            .scaleEffect(leaving ? 1.08 : 1)
            .opacity(leaving ? 0 : 1)
            .blur(radius: leaving ? 8 : 0)
        }
        .ignoresSafeArea()
        .allowsHitTesting(!leaving)
    }
}
