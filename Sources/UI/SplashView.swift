import SwiftUI
import UIKit

/// Launch animation: the five shift lights fill in quickly from left to right, then the
/// APEXDASH letters rise in one by one. Every launch and the onboarding use the same
/// sequence. Calls `onDone` when finished.
///
/// The app runs in landscape only. Opened while the phone is upright, the interface is
/// sideways to the user; the logo then counter-rotates to read upright and shows a hint to
/// turn the phone. Once the phone is turned, the logo rotates into place and only then does
/// the app continue.
struct SplashLogo: View {
    let strings: Strings
    let unit: CGFloat
    var hold: Duration = .milliseconds(900)
    let onDone: () -> Void

    @State private var lit = 0
    @State private var wordmark = false
    /// Rotation (degrees) that keeps the logo upright for the user.
    @State private var angle: Double = 0
    @State private var portrait = false

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
        .overlay(alignment: .bottom) {
            if portrait {
                rotateHint
                    .offset(y: unit * 1.5)
                    .transition(.opacity.combined(with: .offset(y: unit * 0.3)))
            }
        }
        .rotationEffect(.degrees(angle))
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            updateOrientation(animated: false)
        }
        .onDisappear { UIDevice.current.endGeneratingDeviceOrientationNotifications() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateOrientation(animated: true)
        }
        .task { await run() }
    }

    /// A small phone icon tipping over to landscape.
    private var rotateHint: some View {
        VStack(spacing: unit * 0.18) {
            Image(systemName: "iphone")
                .font(.system(size: unit * 0.55, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .phaseAnimator([0.0, 0.0, -90.0, -90.0]) { content, phase in
                    content.rotationEffect(.degrees(phase))
                } animation: { _ in .spring(duration: 0.55, bounce: 0.15) }
            Text(strings.rotatePhone)
                .font(Typeface.font(unit * 0.24, .bold))
                .tracking(unit * 0.05)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize()
        }
    }

    private func run() async {
        try? await Task.sleep(for: .milliseconds(150))
        for step in 1...5 {
            withAnimation(.spring(duration: 0.2, bounce: 0.35)) { lit = step }
            Haptics.impact(.light, intensity: 0.4 + CGFloat(step) * 0.08)
            try? await Task.sleep(for: .milliseconds(90))
        }
        wordmark = true
        try? await Task.sleep(for: .milliseconds(350))
        try? await Task.sleep(for: hold)
        // If the phone is upright, wait for it to be turned; continue after a while if it
        // never is.
        var waited = 0
        while portrait && waited < 80 {
            try? await Task.sleep(for: .milliseconds(100))
            waited += 1
        }
        if waited > 0 { try? await Task.sleep(for: .milliseconds(450)) }
        onDone()
    }

    private func updateOrientation(animated: Bool) {
        let device = UIDevice.current.orientation
        let interface = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.interfaceOrientation }
            .first ?? .landscapeRight
        let target: Double
        switch device {
        // With the home button on the left (landscapeLeft), the top of the interface faces
        // the phone's left edge; held upright, content must rotate right, +90 degrees.
        case .portrait: target = interface == .landscapeLeft ? 90 : -90
        case .portraitUpsideDown: target = interface == .landscapeLeft ? -90 : 90
        case .landscapeLeft, .landscapeRight: target = 0
        // Flat on a table or unknown: leave as is.
        default: return
        }
        let isPortrait = device.isPortrait
        guard target != angle || isPortrait != portrait else { return }
        if animated {
            withAnimation(.spring(duration: 0.7, bounce: 0.18)) {
                angle = target
                portrait = isPortrait
            }
        } else {
            angle = target
            portrait = isPortrait
        }
    }
}

/// The short splash on every launch. It continues from the system's black launch screen and
/// fades out with a slight zoom when done.
struct SplashView: View {
    let strings: Strings
    let unit: CGFloat
    let onDone: () -> Void

    @State private var leaving = false

    var body: some View {
        ZStack {
            Color.black.opacity(leaving ? 0 : 1)
            SplashLogo(strings: strings, unit: unit, hold: .milliseconds(650)) {
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

extension Strings {
    var rotatePhone: String { text("rotatePhone") }
}
