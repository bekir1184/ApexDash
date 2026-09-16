import SwiftUI
import UIKit

/// Ilk acilis tanitimi. Bes sahne: kontak (logo), panolar, oyuna baglanti,
/// sitede analiz ve isiklarin sonmesi. Her sahnenin ogeleri sirayla, yukari
/// kayip netlesarek gelir; sahneler arasi gecis yana kayar ve bulaniklasir.
/// Zemindeki seritler ve kirmizi isima sayfayla birlikte yavasca kayar.
///
/// Son sahne ayni zamanda isik uyarisidir; bu yuzden tanitimi goren
/// kullaniciya ayrica uyari ekrani gosterilmez.
struct OnboardingView: View {
    let strings: Strings
    let unit: CGFloat
    let localIP: String
    let port: Int
    let onFinish: () -> Void

    /// `-onboardingPage N` ile dogrudan bir sahneden baslar; ekran goruntusu icin.
    @State private var page = min(max(UserDefaults.standard.integer(forKey: "onboardingPage"), 0), 4)
    /// Gecis yonu: 1 ileri, -1 geri. Sayfa degismeden once ayri bir
    /// guncellemede yazilir, boylece cikan sahne de dogru yone kayar.
    @State private var direction: CGFloat = 1
    @State private var introDone = UserDefaults.standard.integer(forKey: "onboardingPage") > 0
    @State private var launching = false
    @State private var leaving = false

    private let count = 5

    var body: some View {
        ZStack {
            OnboardingBackdrop(page: page, visible: introDone, unit: unit)

            ZStack {
                scene(page)
                    .id(page)
                    .transition(sceneTransition)
            }
            .padding(.bottom, page == 0 ? 0 : unit * 1.1)

            VStack {
                Spacer()
                footer
                    .padding(.horizontal, unit * 0.9)
                    .padding(.bottom, unit * 0.45)
            }
            .opacity(introDone && !launching ? 1 : 0)
            .animation(.easeOut(duration: 0.5), value: introDone)
            .animation(.easeOut(duration: 0.3), value: launching)
        }
        .scaleEffect(leaving ? 1.18 : 1)
        .blur(radius: leaving ? 24 : 0)
        .opacity(leaving ? 0 : 1)
        .contentShape(Rectangle())
        .gesture(swipe)
    }

    // MARK: - Sahneler

    @ViewBuilder
    private func scene(_ index: Int) -> some View {
        switch index {
        case 0:
            IgnitionScene(strings: strings, unit: unit) { introDone = true }
                .onTapGesture { if introDone { go(to: 1) } }
        case 1:
            DashesScene(strings: strings, unit: unit)
        case 2:
            ConnectScene(strings: strings, unit: unit, localIP: localIP, port: port)
        case 3:
            AnalyseScene(strings: strings, unit: unit)
        default:
            LightsOutScene(strings: strings, unit: unit, running: $launching, onGo: finish)
        }
    }

    private var sceneTransition: AnyTransition {
        let shift = unit * 3 * direction
        return .asymmetric(
            insertion: .modifier(active: SceneShift(x: shift, blur: 14, opacity: 0),
                                 identity: SceneShift(x: 0, blur: 0, opacity: 1)),
            removal: .modifier(active: SceneShift(x: -shift, blur: 14, opacity: 0),
                               identity: SceneShift(x: 0, blur: 0, opacity: 1))
        )
    }

    // MARK: - Alt cubuk

    private var footer: some View {
        HStack {
            Button { go(to: count - 1) } label: {
                Text(strings.obSkip)
                    .font(Typeface.font(unit * 0.24, .bold))
                    .tracking(unit * 0.04)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.vertical, unit * 0.15)
            }
            .buttonStyle(PressScaleStyle())
            .opacity(page < count - 1 ? 1 : 0)
            .frame(width: unit * 2.6, alignment: .leading)

            Spacer()

            ShiftBars(lit: page + 1, barWidth: unit * 0.17, barHeight: unit * 0.38, spacing: unit * 0.1)
                .animation(.spring(duration: 0.5, bounce: 0.3), value: page)

            Spacer()

            Button { go(to: page + 1) } label: {
                HStack(spacing: unit * 0.12) {
                    Text(strings.obNext)
                    Image(systemName: "chevron.right")
                }
                .font(Typeface.font(unit * 0.25, .black))
                .tracking(unit * 0.03)
                .foregroundStyle(Palette.onAccent)
                .padding(.horizontal, unit * 0.42)
                .padding(.vertical, unit * 0.2)
                .background(Capsule().fill(Palette.accent))
                .shadow(color: Palette.accent.opacity(0.55), radius: unit * 0.3)
            }
            .buttonStyle(PressScaleStyle())
            .opacity(page < count - 1 ? 1 : 0)
            .allowsHitTesting(page < count - 1)
            .frame(width: unit * 2.6, alignment: .trailing)
        }
    }

    // MARK: - Gezinme

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard introDone, !launching,
                      abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < -60 { go(to: page + 1) }
                if value.translation.width > 60 { go(to: page - 1) }
            }
    }

    private func go(to target: Int) {
        let target = min(max(target, 0), count - 1)
        guard target != page, introDone, !launching else { return }
        direction = target > page ? 1 : -1
        Haptics.selection()
        DispatchQueue.main.async {
            withAnimation(.spring(duration: 0.7, bounce: 0.12)) { page = target }
        }
    }

    private func finish() {
        withAnimation(.easeIn(duration: 0.6)) {
            leaving = true
        } completion: {
            onFinish()
        }
    }
}

// MARK: - Ortak parcalar

/// Sahne gecisinde yana kayma, bulaniklik ve saydamlik.
private struct SceneShift: ViewModifier {
    let x: CGFloat
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content.offset(x: x).blur(radius: blur).opacity(opacity)
    }
}

/// Ogelerin sirayla gelisi: asagidan kayar, bulaniktan netlesir.
private struct Reveal: ViewModifier {
    let shown: Bool
    let delay: Double
    var distance: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : distance)
            .blur(radius: shown ? 0 : 10)
            .animation(.spring(duration: 0.8, bounce: 0.18).delay(delay), value: shown)
    }
}

private extension View {
    func reveal(_ shown: Bool, _ delay: Double, distance: CGFloat = 22) -> some View {
        modifier(Reveal(shown: shown, delay: delay, distance: distance))
    }
}

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 1) {
        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: intensity)
    }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

/// Uygulama simgesindeki bes egik vites isigi.
struct ShiftBars: View {
    let lit: Int
    let barWidth: CGFloat
    let barHeight: CGFloat
    let spacing: CGFloat
    var glow: CGFloat = 1

    static let colors: [Color] = [
        Color(red: 0.106, green: 0.890, blue: 0.424),
        Color(red: 0.106, green: 0.890, blue: 0.424),
        Color(red: 1.0, green: 0.761, blue: 0.102),
        Color(red: 1.0, green: 0.176, blue: 0.086),
        Color(red: 1.0, green: 0.176, blue: 0.086)
    ]

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<5, id: \.self) { index in
                bar(index)
            }
        }
        // Simgedeki gibi saga yatik (skewX -9 derece).
        .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.158, d: 1, tx: barHeight * 0.079, ty: 0))
    }

    private func bar(_ index: Int) -> some View {
        let on = index < lit
        let colour = Self.colors[index]
        return RoundedRectangle(cornerRadius: barWidth * 0.18, style: .continuous)
            .fill(on ? colour : Color.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: barWidth * 0.18, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(on ? 0.35 : 0), .clear],
                                         startPoint: .top, endPoint: .center))
            )
            .frame(width: barWidth, height: barHeight)
            .shadow(color: on ? colour.opacity(0.85) : .clear, radius: barWidth * 0.55 * glow)
            .shadow(color: on ? colour.opacity(0.45) : .clear, radius: barWidth * 1.4 * glow)
    }
}

/// Zemin: siyahtan acilan seritler ve sayfayla kayan kirmizi isima.
private struct OnboardingBackdrop: View {
    let page: Int
    let visible: Bool
    let unit: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Color.black
                StripedBackground()
                    .frame(width: w * 1.6, height: h)
                    .offset(x: w * 0.25 - CGFloat(page) * w * 0.1)
                    .opacity(visible ? 1 : 0)
                Circle()
                    .fill(RadialGradient(colors: [Palette.accent.opacity(0.28), .clear],
                                         center: .center, startRadius: 0, endRadius: w * 0.4))
                    .frame(width: w * 0.8, height: w * 0.8)
                    .offset(x: glowX(width: w), y: h * 0.45)
                    .opacity(visible ? 1 : 0)
                // Kenarlar hafif karanlik: goz ortada kalsin.
                RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center,
                               startRadius: h * 0.3, endRadius: w * 0.7)
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .ignoresSafeArea()
        .animation(.spring(duration: 1.2, bounce: 0.08), value: page)
        .animation(.easeInOut(duration: 1.4), value: visible)
    }

    private func glowX(width: CGFloat) -> CGFloat {
        let positions: [CGFloat] = [0, 0.25, -0.2, 0.22, 0]
        return width * positions[min(page, positions.count - 1)]
    }
}

/// Bolunmus sahnelerin sol sutunu: numara, baslik, aciklama ve ek icerik.
private struct SceneText<Extra: View>: View {
    let number: Int
    let eyebrow: String
    let title: String
    let message: String
    let unit: CGFloat
    let shown: Bool
    let extra: Extra

    init(number: Int, eyebrow: String, title: String, message: String, unit: CGFloat, shown: Bool,
         @ViewBuilder extra: () -> Extra) {
        self.number = number; self.eyebrow = eyebrow; self.title = title
        self.message = message; self.unit = unit; self.shown = shown
        self.extra = extra()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: unit * 0.18) {
            HStack(spacing: unit * 0.16) {
                Text(verbatim: String(format: "%02d", number))
                    .font(Typeface.digits(unit * 0.26, .black))
                    .foregroundStyle(Palette.accent)
                Capsule().fill(Palette.accent).frame(width: unit * 0.5, height: 2)
                Text(eyebrow)
                    .font(Typeface.font(unit * 0.23, .bold))
                    .tracking(unit * 0.07)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .reveal(shown, 0.05)

            Text(title)
                .font(Typeface.font(unit * 0.62, .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .reveal(shown, 0.12)

            Text(message)
                .font(Typeface.font(unit * 0.26, .medium))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
                .reveal(shown, 0.2)

            extra
        }
        .frame(maxWidth: unit * 6.4, alignment: .leading)
    }
}

/// Sol metin, sag gorsel.
private struct SplitLayout<Left: View, Right: View>: View {
    let unit: CGFloat
    let left: Left
    let right: Right

    init(unit: CGFloat, @ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right) {
        self.unit = unit; self.left = left(); self.right = right()
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: unit * 0.6) {
                left.frame(maxWidth: .infinity, alignment: .leading)
                right.frame(width: geo.size.width * 0.5)
            }
            .padding(.horizontal, unit * 0.9)
            .padding(.top, unit * 0.3)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - 1. Kontak

private struct IgnitionScene: View {
    let strings: Strings
    let unit: CGFloat
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = 0
    @State private var flash = false
    @State private var revealed = false
    @State private var sheen: CGFloat = -1

    private let letters = Array("APEXDASH")

    var body: some View {
        ZStack {
            VStack(spacing: unit * (revealed ? 0.42 : 0)) {
                ShiftBars(lit: lit,
                          barWidth: unit * (revealed ? 0.3 : 0.6),
                          barHeight: unit * (revealed ? 1.0 : 2.3),
                          spacing: unit * (revealed ? 0.17 : 0.32),
                          glow: flash ? 2.4 : 1)

                if revealed {
                    wordmark
                    Text(strings.obTagline)
                        .font(Typeface.font(unit * 0.3, .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .reveal(revealed, 0.75)
                }
            }

            Color.white
                .opacity(flash ? 0.22 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await ignite() }
    }

    private var wordmark: some View {
        HStack(spacing: unit * 0.07) {
            ForEach(letters.indices, id: \.self) { index in
                Text(String(letters[index]))
                    .font(Typeface.font(unit * 0.95, .black))
                    .foregroundStyle(index < 4 ? Color.white : Palette.accent)
                    .reveal(revealed, 0.08 + Double(index) * 0.045, distance: unit * 0.4)
            }
        }
        // Harflerin ustunden bir kez gecen parlama.
        .overlay {
            GeometryReader { geo in
                LinearGradient(colors: [.clear, .white.opacity(0.75), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.35)
                    .rotationEffect(.degrees(18))
                    .offset(x: sheen * geo.size.width * 1.3)
            }
            .mask {
                HStack(spacing: unit * 0.07) {
                    ForEach(letters.indices, id: \.self) { index in
                        Text(String(letters[index])).font(Typeface.font(unit * 0.95, .black))
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func ignite() async {
        try? await Task.sleep(for: .milliseconds(450))
        for step in 1...5 {
            withAnimation(.spring(duration: 0.22, bounce: 0.4)) { lit = step }
            Haptics.impact(step < 4 ? .light : .medium, intensity: 0.5 + CGFloat(step) * 0.1)
            try? await Task.sleep(for: .milliseconds(170))
        }
        try? await Task.sleep(for: .milliseconds(120))

        Haptics.impact(.heavy)
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.09)) { flash = true }
            try? await Task.sleep(for: .milliseconds(110))
        }
        withAnimation(.easeOut(duration: 0.7)) { flash = false }
        withAnimation(.spring(duration: 0.95, bounce: 0.22)) { revealed = true }
        try? await Task.sleep(for: .milliseconds(650))
        Haptics.success()
        withAnimation(.easeInOut(duration: 1.1)) { sheen = 1 }
        onDone()
    }
}

// MARK: - 2. Panolar

private struct DashesScene: View {
    let strings: Strings
    let unit: CGFloat
    @State private var shown = false

    var body: some View {
        SplitLayout(unit: unit) {
            SceneText(number: 1, eyebrow: strings.obDashesEyebrow, title: strings.obDashesTitle,
                      message: strings.obDashesBody, unit: unit, shown: shown) { EmptyView() }
        } right: {
            DashCarousel(strings: strings, unit: unit)
                .reveal(shown, 0.25, distance: unit * 0.8)
        }
        .task { shown = true }
    }
}

/// Kendi kendine donen uc kart; ondeki pano canli oynar.
private struct DashCarousel: View {
    let strings: Strings
    let unit: CGFloat

    @State private var index = 0
    private let themes: [DashTheme] = [.cluster, .broadcast, .dotMatrix, .modern, .realistic, .game]

    private var screen: CGSize {
        let b = UIScreen.main.bounds.size
        return CGSize(width: max(b.width, b.height), height: min(b.width, b.height))
    }

    var body: some View {
        GeometryReader { geo in
            let cardW = geo.size.width * 0.8
            VStack(spacing: unit * 0.35) {
                ZStack {
                    ForEach(themes.indices, id: \.self) { i in
                        let k = relative(i)
                        if abs(k) <= 1 {
                            card(themes[i], width: cardW, front: k == 0)
                                .scaleEffect(k == 0 ? 1 : 0.74)
                                .rotation3DEffect(.degrees(Double(-k) * 32), axis: (0, 1, 0), perspective: 0.45)
                                .offset(x: CGFloat(k) * cardW * 0.36)
                                .opacity(k == 0 ? 1 : 0.5)
                                .brightness(k == 0 ? 0 : -0.15)
                                .zIndex(k == 0 ? 2 : 1)
                                .transition(.opacity.combined(with: .scale(scale: 0.6)))
                        }
                    }
                }
                .frame(height: cardW * screen.height / screen.width)

                Text(strings.themeTitle(themes[index]))
                    .font(Typeface.font(unit * 0.26, .black))
                    .tracking(unit * 0.08)
                    .foregroundStyle(.white.opacity(0.8))
                    .contentTransition(.numericText())
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.6))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.85, bounce: 0.16)) { index = (index + 1) % themes.count }
                Haptics.impact(.soft, intensity: 0.5)
            }
        }
    }

    private func relative(_ i: Int) -> Int {
        var d = i - index
        let n = themes.count
        if d > n / 2 { d -= n }
        if d < -n / 2 { d += n }
        return d
    }

    private func card(_ theme: DashTheme, width: CGFloat, front: Bool) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !front)) { context in
            DashboardCard(theme: theme, dash: .onboardingDemo(at: context.date), strings: strings,
                          fullSize: screen, width: width, cornerRadius: unit * 0.3)
        }
    }
}

extension DashboardModel {
    /// Tanitimdaki canli ornek: vitesleri sirayla cikan bir duzluk.
    static func onboardingDemo(at date: Date) -> DashboardModel {
        var m = DashboardModel.demo
        let t = date.timeIntervalSinceReferenceDate
        let run = (t / 6).truncatingRemainder(dividingBy: 1)            // 6 sn'lik dongu
        let gears = 4.0
        let inGear = (run * gears).truncatingRemainder(dividingBy: 1)
        m.gear = 5 + Int(run * gears)
        m.rpm = 9_200 + Int(inGear * 3_200)
        m.revLightsPercent = Int(inGear * 100)
        let lights = Int(inGear * 15)
        m.revLightsBits = lights <= 0 ? 0 : UInt16((1 << min(lights, 15)) - 1)
        m.speedKPH = 212 + Int(run * 105)
        m.throttle = 1
        m.currentLapTimeMS = 41_236 + Int((t * 1000).truncatingRemainder(dividingBy: 20_000))
        m.gLateral = Float(sin(t * 1.3) * 0.6)
        m.gLongitudinal = Float(0.4 + cos(t * 0.9) * 0.2)
        return m
    }
}

// MARK: - 3. Baglanti

private struct ConnectScene: View {
    let strings: Strings
    let unit: CGFloat
    let localIP: String
    let port: Int
    @State private var shown = false

    var body: some View {
        SplitLayout(unit: unit) {
            SceneText(number: 2, eyebrow: strings.obConnectEyebrow, title: strings.obConnectTitle,
                      message: strings.obConnectBody, unit: unit, shown: shown) {
                VStack(spacing: 0) {
                    row(strings.obUDP, strings.obOn, colour: Palette.live, delay: 0.3)
                    Divider().overlay(Color.white.opacity(0.08))
                    row("IP", localIP, colour: .white, delay: 0.38)
                    Divider().overlay(Color.white.opacity(0.08))
                    row("PORT", "\(port)", colour: .white, delay: 0.46)
                }
                .padding(.horizontal, unit * 0.3)
                .background(RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous).fill(Palette.deep.opacity(0.9)))
                .overlay(RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.top, unit * 0.1)
                .reveal(shown, 0.28)
            }
        } right: {
            PacketFlow(unit: unit, shown: shown)
        }
        .task { shown = true }
    }

    private func row(_ title: String, _ value: String, colour: Color, delay: Double) -> some View {
        HStack {
            Text(title)
                .font(Typeface.font(unit * 0.22, .bold))
                .tracking(unit * 0.05)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(verbatim: value)
                .font(Typeface.digits(unit * 0.3, .black))
                .foregroundStyle(colour)
        }
        .padding(.vertical, unit * 0.11)
        .reveal(shown, delay, distance: unit * 0.15)
    }
}

/// Oyundan telefona akan paketler.
private struct PacketFlow: View {
    let unit: CGFloat
    let shown: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let a = CGPoint(x: w * 0.17, y: h * 0.56)
            let b = CGPoint(x: w * 0.83, y: h * 0.56)
            let c = CGPoint(x: w * 0.5, y: h * 0.02)
            ZStack {
                Path { p in p.move(to: a); p.addQuadCurve(to: b, control: c) }
                    .trim(from: 0, to: shown ? 1 : 0)
                    .stroke(Color.white.opacity(0.2),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 7]))
                    .animation(.easeInOut(duration: 1.1).delay(0.45), value: shown)

                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    Canvas { g, _ in
                        for k in 0..<8 {
                            let f = (t * 0.5 + Double(k) / 8).truncatingRemainder(dividingBy: 1)
                            let pt = quad(a, c, b, CGFloat(f))
                            let fade = sin(f * .pi)
                            let r = unit * 0.065
                            g.fill(Path(ellipseIn: CGRect(x: pt.x - r * 3, y: pt.y - r * 3, width: r * 6, height: r * 6)),
                                   with: .color(Palette.accent.opacity(0.22 * fade)))
                            g.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                                   with: .color(Color(red: 1, green: 0.42, blue: 0.36).opacity(fade)))
                        }
                    }
                }
                .opacity(shown ? 1 : 0)
                .animation(.easeIn(duration: 0.5).delay(1.2), value: shown)

                Text(verbatim: "UDP · 60 Hz")
                    .font(Typeface.digits(unit * 0.22, .black))
                    .tracking(unit * 0.04)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, unit * 0.22)
                    .padding(.vertical, unit * 0.08)
                    .background(Capsule().fill(Palette.deep))
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .position(x: w * 0.5, y: h * 0.4)
                    .reveal(shown, 1.3, distance: unit * 0.2)

                device(symbol: "gamecontroller.fill", label: "F1 25 · F1 26", rotate: 0)
                    .position(a)
                    .reveal(shown, 0.3)
                device(symbol: "iphone.gen3.radiowaves.left.and.right", label: "APEX DASH", rotate: 0)
                    .position(b)
                    .reveal(shown, 0.4)
            }
        }
    }

    private func device(symbol: String, label: String, rotate: Double) -> some View {
        VStack(spacing: unit * 0.18) {
            ZStack {
                RoundedRectangle(cornerRadius: unit * 0.35, style: .continuous)
                    .fill(LinearGradient(colors: [Palette.deep, Palette.ground], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: unit * 0.35, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1))
                    .shadow(color: .black.opacity(0.5), radius: unit * 0.3, y: unit * 0.15)
                Image(systemName: symbol)
                    .font(.system(size: unit * 0.62, weight: .semibold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(rotate))
            }
            .frame(width: unit * 1.55, height: unit * 1.55)
            Text(verbatim: label)
                .font(Typeface.font(unit * 0.2, .bold))
                .tracking(unit * 0.04)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private func quad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x,
                       y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
    }
}

// MARK: - 4. Analiz

private struct AnalyseScene: View {
    let strings: Strings
    let unit: CGFloat
    @State private var shown = false

    var body: some View {
        SplitLayout(unit: unit) {
            SceneText(number: 3, eyebrow: strings.obAnalyseEyebrow, title: strings.obAnalyseTitle,
                      message: strings.obAnalyseBody, unit: unit, shown: shown) {
                VStack(spacing: unit * 0.06) {
                    lap(11, "1:29.104", gap: "+0.692", best: false, delay: 0.3)
                    lap(12, "1:28.412", gap: strings.obBest, best: true, delay: 0.38)
                    lap(13, "1:28.967", gap: "+0.555", best: false, delay: 0.46)
                }
                .padding(.top, unit * 0.1)
            }
        } right: {
            TrackTrace(unit: unit, shown: shown)
        }
        .task { shown = true }
    }

    private func lap(_ number: Int, _ time: String, gap: String, best: Bool, delay: Double) -> some View {
        let purple = Color(red: 0.71, green: 0.36, blue: 1)
        return HStack(spacing: unit * 0.3) {
            Text(verbatim: "\(strings.obLap) \(number)")
                .font(Typeface.font(unit * 0.22, .bold))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: unit * 1.2, alignment: .leading)
            Text(verbatim: time)
                .font(Typeface.digits(unit * 0.32, .black))
                .foregroundStyle(best ? purple : .white)
            Spacer()
            Text(verbatim: gap)
                .font(Typeface.digits(unit * 0.22, .bold))
                .foregroundStyle(best ? purple : Color(red: 0.96, green: 0.85, blue: 0.17))
        }
        .padding(.horizontal, unit * 0.28)
        .padding(.vertical, unit * 0.08)
        .background(RoundedRectangle(cornerRadius: unit * 0.18, style: .continuous)
            .fill(best ? purple.opacity(0.14) : Palette.deep.opacity(0.85)))
        .reveal(shown, delay, distance: unit * 0.2)
    }
}

/// Kendini cizen pist ve etrafinda donen arac.
private struct TrackTrace: View {
    let unit: CGFloat
    let shown: Bool

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size).insetBy(dx: unit * 0.8, dy: unit * 0.55)
            ZStack {
                TrackShape()
                    .trim(from: 0, to: shown ? 1 : 0)
                    .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: unit * 0.36, lineCap: .round, lineJoin: .round))
                TrackShape()
                    .trim(from: 0, to: shown ? 1 : 0)
                    .stroke(AngularGradient(colors: [.blue, .green, .yellow, .red, .yellow, .green, .blue], center: .center),
                            style: StrokeStyle(lineWidth: unit * 0.09, lineCap: .round, lineJoin: .round))
                    .shadow(color: .white.opacity(0.15), radius: unit * 0.1)

                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let p = TrackShape.point((t / 7).truncatingRemainder(dividingBy: 1), in: rect)
                    Circle()
                        .fill(Color.white)
                        .frame(width: unit * 0.2, height: unit * 0.2)
                        .shadow(color: .white, radius: unit * 0.15)
                        .shadow(color: Palette.accent, radius: unit * 0.35)
                        .position(p)
                }
                .opacity(shown ? 1 : 0)
                .animation(.easeIn(duration: 0.5).delay(1.8), value: shown)
            }
            .padding(0)
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.easeInOut(duration: 1.6).delay(0.3), value: shown)
        }
    }
}

private struct TrackShape: Shape {
    /// Kapali, pist benzeri bir egri: birkac harmonik ile bozulmus elips.
    static func point(_ f: Double, in rect: CGRect) -> CGPoint {
        let theta = f * 2 * .pi
        let r = 1 + 0.2 * sin(2 * theta) + 0.12 * cos(3 * theta + 0.8) + 0.05 * sin(5 * theta + 0.3)
        let x = cos(theta) * r / 1.35
        let y = sin(theta) * r / 1.35
        return CGPoint(x: rect.midX + CGFloat(x) * rect.width / 2,
                       y: rect.midY + CGFloat(y) * rect.height / 2)
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 260
        for i in 0...steps {
            let p = Self.point(Double(i) / Double(steps), in: rect)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }
}

// MARK: - 5. Isiklar sonsun

private struct LightsOutScene: View {
    let strings: Strings
    let unit: CGFloat
    @Binding var running: Bool
    let onGo: () -> Void

    @State private var shown = false
    @State private var lit = 0

    var body: some View {
        VStack(spacing: unit * 0.36) {
            Text(strings.obReadyTitle)
                .font(Typeface.font(unit * 0.8, .black))
                .foregroundStyle(.white)
                .reveal(shown, 0.05)

            StartLightsView(litColumns: lit, unit: unit * 0.95)
                .reveal(shown, 0.15)

            HStack(alignment: .top, spacing: unit * 0.16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Palette.alert)
                Text(strings.obWarning)
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(Typeface.font(unit * 0.22, .medium))
            .frame(maxWidth: unit * 9)
            .opacity(running ? 0 : 1)
            .reveal(shown, 0.25)

            Button(action: start) {
                Text(strings.obLightsOut)
                    .font(Typeface.font(unit * 0.32, .black))
                    .tracking(unit * 0.06)
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, unit * 0.9)
                    .padding(.vertical, unit * 0.26)
                    .background(Capsule().fill(Palette.accent))
                    .shadow(color: Palette.accent.opacity(0.6), radius: unit * 0.4)
            }
            .buttonStyle(PressScaleStyle())
            .disabled(running)
            .opacity(running ? 0 : 1)
            .animation(.easeOut(duration: 0.25), value: running)
            .reveal(shown, 0.35)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { shown = true }
    }

    /// Gercek start prosedurü: bes kolon birer birer yanar, bekler, soner.
    private func start() {
        guard !running else { return }
        running = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            for column in 1...5 {
                withAnimation(.spring(duration: 0.18, bounce: 0.3)) { lit = column }
                Haptics.impact(.heavy, intensity: 0.55 + CGFloat(column) * 0.09)
                try? await Task.sleep(for: .milliseconds(620))
            }
            try? await Task.sleep(for: .milliseconds(Int.random(in: 350...900)))
            withAnimation(.easeOut(duration: 0.06)) { lit = 0 }
            Haptics.success()
            try? await Task.sleep(for: .milliseconds(180))
            onGo()
        }
    }
}

// MARK: - Metinler

extension Strings {
    var obTagline: String { pick("Telefonun artık bir yarış direksiyonu ekranı.", "Your phone is now a racing wheel display.") }
    var obNext: String { pick("DEVAM", "NEXT") }
    var obSkip: String { pick("ATLA", "SKIP") }

    var obDashesEyebrow: String { pick("PANOLAR", "DASHBOARDS") }
    var obDashesTitle: String { pick("KOKPİTİNİ SEÇ", "PICK YOUR COCKPIT") }
    var obDashesBody: String {
        pick("Altı farklı pano; F1 25 ve F1 26 telemetrisiyle anlık. Menüde kaydır, dokun ve sür.",
             "Six dashboards, live from F1 25 and F1 26 telemetry. Swipe in the menu, tap and drive.")
    }

    var obConnectEyebrow: String { pick("BAĞLANTI", "CONNECTION") }
    var obConnectTitle: String { pick("OYUNA BAĞLAN", "CONNECT THE GAME") }
    var obConnectBody: String {
        pick("Oyunda Ayarlar › Telemetri'de UDP'yi aç ve bu adresi gir. Telefon ve oyun aynı ağda olsun.",
             "In the game, turn on UDP under Settings › Telemetry and enter this address. Keep both on the same network.")
    }
    var obUDP: String { pick("UDP TELEMETRİ", "UDP TELEMETRY") }
    var obOn: String { pick("AÇIK", "ON") }

    var obAnalyseEyebrow: String { pick("ANALİZ", "ANALYSIS") }
    var obAnalyseTitle: String { pick("HER TURU İNCELE", "STUDY EVERY LAP") }
    var obAnalyseBody: String {
        pick("Laptopta apexdash.pro'yu aç ve QR'ı okut: harita, hız ve pedal grafikleri, viraj viraj karşılaştırma.",
             "Open apexdash.pro on a laptop and scan the QR: track map, speed and pedal traces, corner-by-corner comparison.")
    }
    var obBest: String { pick("EN İYİ", "BEST") }
    var obLap: String { pick("TUR", "LAP") }

    var obReadyTitle: String { pick("HAZIR MISIN?", "READY?") }
    var obLightsOut: String { pick("IŞIKLAR SÖNSÜN", "LIGHTS OUT") }
    var obWarning: String {
        pick("Vites uyarısında ekran hızla yanıp söner; flaş ayarlardan açılabilir. Işığa duyarlı epilepsin varsa bu uyarıları kapalı tut.",
             "The screen flashes at the shift point and the phone's flash can be enabled in settings. If you have photosensitive epilepsy, keep these off.")
    }
}
