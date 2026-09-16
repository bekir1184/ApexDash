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
            IgnitionScene(strings: strings, unit: unit) {
                introDone = true
                go(to: 1)
            }
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

// MARK: - 1. Acilis

/// Kisa acilis ekrani: logo ve yazi yumusakca belirir, kisa bir an durur,
/// tanitim kendiliginden ilk sahneye gecer.
private struct IgnitionScene: View {
    let strings: Strings
    let unit: CGFloat
    let onDone: () -> Void

    var body: some View {
        SplashLogo(unit: unit, onDone: onDone)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// Koyu sehir haritasi ustunde kendini cizen beyaz sokak pisti (Monako
/// duzeni) ve pistte donen arac. Harita tamamen kodla cizilir: yapilar ve
/// sokaklar sabit tohumlu rastgele uretilir, deniz ve liman siyahtir.
private struct TrackTrace: View {
    let unit: CGFloat
    let shown: Bool

    var body: some View {
        GeometryReader { geo in
            let height = min(geo.size.height * 0.96, geo.size.width / StreetCircuit.aspect)
            let size = CGSize(width: height * StreetCircuit.aspect, height: height)
            ZStack {
                // Sehir zemine karisir: kart yok, kenarlar yumusakca kaybolur.
                Canvas { context, canvasSize in
                    StreetCircuit.drawCity(in: &context, size: canvasSize)
                }
                .mask(RadialGradient(colors: [.white, .white.opacity(0.6), .clear], center: .center,
                                     startRadius: size.width * 0.2, endRadius: size.height * 0.62))

                // Pistin isimasi, sonra kendisi.
                CircuitShape()
                    .trim(from: 0, to: shown ? 1 : 0)
                    .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: unit * 0.22, lineCap: .round, lineJoin: .round))
                    .blur(radius: unit * 0.14)
                CircuitShape()
                    .trim(from: 0, to: shown ? 1 : 0)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: unit * 0.085, lineCap: .round, lineJoin: .round))

                // Tunel: beyaz cizginin ustunde kesik kesik karartma.
                CircuitShape(range: StreetCircuit.tunnel)
                    .stroke(Color.black.opacity(0.75),
                            style: StrokeStyle(lineWidth: unit * 0.1, dash: [unit * 0.035, unit * 0.045]))
                    .opacity(shown ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(1.2), value: shown)

                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let f = (t / 9).truncatingRemainder(dividingBy: 1)
                    let p = StreetCircuit.point(at: f)
                    Circle()
                        .fill(Palette.accent)
                        .overlay(Circle().stroke(Color.white, lineWidth: unit * 0.035))
                        .frame(width: unit * 0.24, height: unit * 0.24)
                        .shadow(color: Palette.accent, radius: unit * 0.25)
                        .position(x: p.x * size.width, y: p.y * size.height)
                }
                .opacity(shown ? 1 : 0)
                .animation(.easeIn(duration: 0.5).delay(1.9), value: shown)
            }
            .frame(width: size.width, height: size.height)
            .animation(.easeInOut(duration: 1.8).delay(0.35), value: shown)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private struct CircuitShape: Shape {
    var range: Range<Int>? = nil

    func path(in rect: CGRect) -> Path {
        let points = StreetCircuit.points
        let indices = range.map { Array($0) } ?? Array(points.indices) + [0]
        var path = Path()
        for (n, i) in indices.enumerated() {
            let p = CGPoint(x: rect.minX + points[i].x * rect.width, y: rect.minY + points[i].y * rect.height)
            if n == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }
}

/// Pist ve cevresindeki sehir; koordinatlar 846 x 930'luk bir haritada.
private enum StreetCircuit {
    static let mapSize = CGSize(width: 846, height: 930)
    static var aspect: CGFloat { mapSize.width / mapSize.height }

    private static let raw: [CGPoint] = [
        (178, 484), (260, 472), (340, 461), (390, 452), (470, 428), (540, 405),
        (575, 392), (630, 360), (675, 318), (700, 275), (712, 230), (720, 180), (724, 130), (722, 95),
        (715, 78), (695, 80), (665, 92), (656, 104), (662, 125), (672, 148), (682, 158), (688, 150),
        (684, 135), (668, 110), (648, 88), (630, 76), (615, 90), (580, 135), (545, 178), (518, 210),
        (515, 232), (530, 255), (552, 285), (560, 310), (552, 338), (530, 358), (480, 372), (420, 392),
        (370, 410), (300, 428), (220, 445), (140, 462), (125, 480), (120, 540), (118, 620), (122, 700),
        (135, 780), (160, 840), (190, 888), (230, 892), (262, 885), (262, 872), (240, 850), (210, 800),
        (190, 760), (182, 735), (190, 710), (178, 660), (160, 630), (152, 590), (150, 540), (160, 500)
    ].map { CGPoint(x: $0.0, y: $0.1) }

    /// 0...1 araliginda pist noktalari.
    static let points: [CGPoint] = raw.map { CGPoint(x: $0.x / mapSize.width, y: $0.y / mapSize.height) }
    /// Limandan yukari cikan tunel.
    static let tunnel = 6..<14

    /// Kapali pist boyunca birikimli uzunluk; arac sabit hizla ilerlesin.
    private static let lengths: [CGFloat] = {
        var out: [CGFloat] = [0]
        let closed = raw + [raw[0]]
        for i in 1..<closed.count {
            out.append(out[i - 1] + hypot(closed[i].x - closed[i - 1].x, closed[i].y - closed[i - 1].y))
        }
        return out
    }()

    static func point(at fraction: Double) -> CGPoint {
        let closed = points + [points[0]]
        let target = CGFloat(fraction) * lengths[lengths.count - 1]
        var i = 1
        while i < lengths.count - 1 && lengths[i] < target { i += 1 }
        let span = max(lengths[i] - lengths[i - 1], 0.001)
        let f = (target - lengths[i - 1]) / span
        return CGPoint(x: closed[i - 1].x + (closed[i].x - closed[i - 1].x) * f,
                       y: closed[i - 1].y + (closed[i].y - closed[i - 1].y) * f)
    }

    /// Liman ve acik deniz.
    private static let sea: [CGPoint] = [
        (185, 500), (560, 412), (690, 335), (748, 150), (790, 60), (846, 40), (846, 930),
        (600, 930), (560, 860), (275, 900), (228, 800), (200, 700), (172, 600), (165, 520)
    ].map { CGPoint(x: $0.0, y: $0.1) }

    private struct Block { let rect: CGRect; let shade: Double }

    private static let city: (blocks: [Block], streets: [[CGPoint]]) = {
        var seed: UInt64 = 0x5EED_A9E7
        func random() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 33) / CGFloat(UInt64(1) << 31)
        }
        func nearTrack(_ p: CGPoint, _ margin: CGFloat) -> Bool {
            let closed = raw + [raw[0]]
            for i in 1..<closed.count where distance(p, closed[i - 1], closed[i]) < margin { return true }
            return false
        }

        var streets: [[CGPoint]] = []
        while streets.count < 24 {
            var p = CGPoint(x: random() * mapSize.width, y: random() * mapSize.height)
            guard !inside(p, sea) else { continue }
            var angle = random() * .pi * 2
            var line = [p]
            for _ in 0..<7 {
                angle += (random() - 0.5) * 0.9
                let length = 50 + random() * 90
                let next = CGPoint(x: p.x + cos(angle) * length, y: p.y + sin(angle) * length)
                if inside(next, sea) { break }
                line.append(next); p = next
            }
            if line.count > 2 { streets.append(line) }
        }

        var blocks: [Block] = []
        var tries = 0
        while blocks.count < 360 && tries < 6000 {
            tries += 1
            let w = 12 + random() * 38, h = 10 + random() * 34
            let c = CGPoint(x: random() * mapSize.width, y: random() * mapSize.height)
            guard !inside(c, sea), !nearTrack(c, 18 + max(w, h) * 0.6) else { continue }
            let rect = CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
            guard !blocks.contains(where: { $0.rect.insetBy(dx: -4, dy: -4).intersects(rect) }) else { continue }
            blocks.append(Block(rect: rect, shade: Double(0.2 + random() * 0.07)))
        }
        return (blocks, streets)
    }()

    static func drawCity(in context: inout GraphicsContext, size: CGSize) {
        let k = size.width / mapSize.width
        let sy = size.height / mapSize.height

        for line in city.streets {
            var path = Path()
            for (n, p) in line.enumerated() {
                let q = CGPoint(x: p.x * k, y: p.y * sy)
                if n == 0 { path.move(to: q) } else { path.addLine(to: q) }
            }
            context.stroke(path, with: .color(Color.white.opacity(0.06)),
                           style: StrokeStyle(lineWidth: max(1.2, 5 * k), lineCap: .round, lineJoin: .round))
        }
        for block in city.blocks {
            let r = CGRect(x: block.rect.minX * k, y: block.rect.minY * sy,
                           width: block.rect.width * k, height: block.rect.height * sy)
            context.fill(Path(roundedRect: r, cornerRadius: 1.5), with: .color(Color.white.opacity(block.shade - 0.13)))
        }

    }

    private static func inside(_ p: CGPoint, _ polygon: [CGPoint]) -> Bool {
        var result = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let a = polygon[i], b = polygon[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { result.toggle() }
            j = i
        }
        return result
    }

    private static func distance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / max(dx * dx + dy * dy, 0.001)))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
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
