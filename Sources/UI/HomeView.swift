import SwiftUI

/// The menu: dashboards side by side in a horizontal carousel, the selected one in front
/// and larger. Scrolling uses the system ScrollView (momentum, rubber banding and
/// deceleration are the system's own curves), and the card transitions follow the finger
/// through scrollTransition. The list repeats the dashboards so it scrolls endlessly, and
/// quietly recentres when idle.
struct HomeView: View {
    /// Not observed: previews read it from TimelineViews, so six dashboards are not redrawn
    /// for every packet.
    let client: TelemetryClient
    let strings: Strings
    let unit: CGFloat
    @Binding var selectedTheme: DashTheme
    let onSelect: () -> Void
    let onLaps: () -> Void
    let onSettings: () -> Void
    let onOpenSetup: () -> Void
    /// The centre card is hidden while the full-screen dashboard sits in its place.
    var hidesCentreCard = false
    /// During a transition, previews draw this frozen data.
    var frozenDash: DashboardModel? = nil

    @State private var position: Int?
    /// Warm-up animation of the card just landed on: which card, and when it started.
    @State private var warmUpIndex: Int?
    @State private var warmUpStart: Date = .distantPast
    /// Redraw at the display rate while warming up; 10 Hz is enough otherwise.
    @State private var warming = false
    @State private var warmUpEnd: Task<Void, Never>?
    @State private var showsConnection = false
    @State private var tour: Task<Void, Never>?

    private let themes = DashTheme.allCases
    /// An odd number of repeats keeps the middle block exactly in the middle.
    private let repeats = 9
    private var itemCount: Int { themes.count * repeats }
    private var middleBase: Int { themes.count * (repeats / 2) }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let cardW = size.width * 0.53, cardH = cardW * size.height / size.width
            ZStack {
                StripedBackground()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, unit * 0.5)
                    Spacer(minLength: 0)
                    carousel(size: size, cardW: cardW, cardH: cardH)
                        .frame(height: cardH * 1.12)
                    themeTitle
                        .padding(.top, unit * 0.18)
                    Spacer(minLength: 0)
                    footer
                        .padding(.horizontal, unit * 0.5)
                }
                .padding(.vertical, unit * 0.3)
            }
            .overlay(alignment: .topTrailing) {
                if showsConnection {
                    ConnectionCard(client: client, strings: strings, unit: unit * 0.62,
                                   onOpenSetup: { showsConnection = false; onOpenSetup() },
                                   onClose: { showsConnection = false })
                        .padding(.top, unit * 0.95)
                        .padding(.trailing, unit * 0.5)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.15), value: showsConnection)
            .onAppear {
                if position == nil { position = middleBase + (themes.firstIndex(of: selectedTheme) ?? 0) }
                startMenuTourIfRequested()
            }
            .onChange(of: position) { old, new in
                guard let new else { return }
                let theme = themes[new % themes.count]
                // Jumping to another copy of the same dashboard, for endless scrolling,
                // does not replay the animation.
                if old.map({ themes[$0 % themes.count] }) != theme {
                    warmUpIndex = new
                    // The first card waits for the launch splash to finish; other cards
                    // wait briefly for the scroll to settle.
                    let delay = old == nil ? 2.3 : 0.45
                    warmUpStart = Date().addingTimeInterval(delay)
                    warming = true
                    warmUpEnd?.cancel()
                    warmUpEnd = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(delay + DashboardModel.warmUpDuration + 0.1))
                        guard !Task.isCancelled else { return }
                        warming = false
                    }
                } else if warmUpIndex == old {
                    warmUpIndex = new
                }
                if theme != selectedTheme { selectedTheme = theme }
            }
            .onChange(of: selectedTheme) { _, new in
                // A selection from outside (swiping in full screen): move to the nearest
                // copy.
                guard let current = position, themes[current % themes.count] != new else { return }
                let target = nearestIndex(of: new, to: current)
                withAnimation(.spring(duration: 0.45, bounce: 0.1)) { position = target }
            }
        }
    }

    // MARK: Top bar

    private var header: some View {
        HStack {
            HStack(spacing: 0) {
                Text(verbatim: "APEX")
                    .font(Typeface.font(unit * 0.52, .black))
                    .foregroundStyle(.white)
                + Text(verbatim: "DASH")
                    .font(Typeface.font(unit * 0.52, .black))
                    .foregroundStyle(Palette.accent)
            }
            .tracking(unit * 0.06)

            Spacer()

            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                ConnectionBadge(status: client.status, hz: client.packetsPerSecond,
                                isDemo: client.isDemoRunning, strings: strings, unit: unit) {
                    if client.isDemoRunning { client.stopDemo() }
                    else if client.status != .receiving { showsConnection.toggle() }
                }
            }
        }
    }

    /// `-menuTour YES` walks through the dashboards on its own, for recording
    /// the menu without a hand on the screen.
    private func startMenuTourIfRequested() {
        guard UserDefaults.standard.bool(forKey: "menuTour"), tour == nil else { return }
        tour = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            while !Task.isCancelled {
                withAnimation(.spring(duration: 0.55, bounce: 0.12)) { position = (position ?? 0) + 1 }
                try? await Task.sleep(for: .seconds(2.2))
            }
        }
    }

    // MARK: Carousel

    /// The data a card shows right now. Without a connection the dashboards stay cold; only
    /// the card just landed on comes alive once.
    private func dash(for index: Int, at date: Date) -> DashboardModel {
        if let frozenDash { return frozenDash }
        if client.status == .receiving { return client.dash }
        let elapsed = date.timeIntervalSince(warmUpStart)
        guard index == warmUpIndex, elapsed < DashboardModel.warmUpDuration else { return .cold }
        return .warmUp(at: elapsed)
    }

    private func carousel(size: CGSize, cardW: CGFloat, cardH: CGFloat) -> some View {
        let sidePad = (size.width - cardW) / 2
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(0..<itemCount, id: \.self) { index in
                    let theme = themes[index % themes.count]
                    let isCentre = index == position
                    // Each card has its own clock: only the warming card redraws at the
                    // display rate, the others at 10 Hz (for live data).
                    TimelineView(.animation(minimumInterval: warming && index == warmUpIndex ? nil : 0.1)) { context in
                        DashboardCard(theme: theme, dash: dash(for: index, at: context.date), strings: strings,
                                      fullSize: size, width: cardW, cornerRadius: unit * 0.35,
                                      highlighted: isCentre, halo: isCentre)
                    }
                        .opacity(isCentre && hidesCentreCard ? 0 : 1)
                        .background {
                            if isCentre {
                                GeometryReader { g in
                                    Color.clear.preference(key: CardFrameKey.self, value: g.frame(in: .global))
                                }
                            }
                        }
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(1 - abs(phase.value) * 0.4)
                                .opacity(1 - abs(phase.value) * 0.45)
                        }
                        .frame(width: cardW, height: cardH)
                        .onTapGesture {
                            if isCentre { onSelect() }
                            else { withAnimation(.spring(duration: 0.45, bounce: 0.1)) { position = index } }
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
        .safeAreaPadding(.horizontal, sidePad)
        .scrollPosition(id: $position)
        .frame(width: size.width)
        .modifier(RecentreOnIdle(recentre: recentreIfNearEdge))
    }

    /// Endless scrolling: near either end, while nobody is looking, jump to the equivalent
    /// card in the middle of the list. The position stays on the same card, so it is
    /// invisible.
    private func recentreIfNearEdge() {
        guard let current = position else { return }
        let band = themes.count * 2
        guard current < band || current > itemCount - band else { return }
        var still = Transaction(); still.disablesAnimations = true
        withTransaction(still) { position = middleBase + current % themes.count }
    }

    private func nearestIndex(of theme: DashTheme, to current: Int) -> Int {
        let want = themes.firstIndex(of: theme) ?? 0
        let base = current - current % themes.count
        let candidates = [base + want - themes.count, base + want, base + want + themes.count]
        return candidates.min { abs($0 - current) < abs($1 - current) } ?? current
    }

    private var themeTitle: some View {
        Text(strings.themeTitle(selectedTheme))
            .font(Typeface.font(unit * 0.34, .black))
            .foregroundStyle(.white)
            .tracking(unit * 0.05)
            .contentTransition(.numericText())
            .animation(.spring(duration: 0.3), value: selectedTheme)
    }

    // MARK: Bottom bar

    private var footer: some View {
        ZStack {
            HStack {
                pill(strings.lapsButton, action: onLaps)
                Spacer()
                pill(strings.settingsButton, action: onSettings)
            }
            Button(action: onSelect) {
                Text(strings.selectButton)
                    .font(Typeface.font(unit * 0.32, .black))
                    .foregroundStyle(Palette.onAccent)
                    .tracking(unit * 0.05)
                    .padding(.horizontal, unit * 1.1)
                    .padding(.vertical, unit * 0.2)
                    .background(Capsule().fill(Palette.accent))
            }
            .buttonStyle(PressScaleStyle())
        }
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typeface.font(unit * 0.24, .black))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, unit * 0.36)
                .padding(.vertical, unit * 0.14)
                .background(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// Recentres the list when scrolling stops. iOS 18 reports the scroll phase directly; on
/// iOS 17 it is tried shortly after the finger lifts.
struct RecentreOnIdle: ViewModifier {
    let recentre: () -> Void
    @State private var pending: Task<Void, Never>?

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollPhaseChange { _, phase in
                if phase == .idle { recentre() }
            }
        } else {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 4).onEnded { _ in
                    pending?.cancel()
                    pending = Task { @MainActor in
                        // Wait for momentum to end, then recentre quietly.
                        try? await Task.sleep(for: .milliseconds(700))
                        guard !Task.isCancelled else { return }
                        recentre()
                    }
                }
            )
        }
    }
}

/// Shrinks slightly while pressed, like system buttons.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.2), value: configuration.isPressed)
    }
}

/// A dashboard card: the dashboard is drawn at full-screen size and scaled to `width`.
/// Carousel cards and the full-screen stage use the same view, so they match pixel for
/// pixel when they overlap.
struct DashboardCard: View {
    let theme: DashTheme
    let dash: DashboardModel
    let strings: Strings
    let fullSize: CGSize
    let width: CGFloat
    let cornerRadius: CGFloat
    var highlighted = false
    /// Selected card: the screen's own colours glow softly past its edges.
    var halo = false

    var body: some View {
        let feather = halo ? cornerRadius * 0.22 : 0
        screen
            // The selected card's edge blends softly into the background.
            .mask {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .padding(feather)
                    .blur(radius: feather)
            }
            // Thin frame in the same grey as the background stripes.
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Palette.stripeFar, lineWidth: 1.5)
            }
            .background {
                if halo {
                    screen
                        .scaleEffect(1.04)
                        .blur(radius: cornerRadius * 0.7)
                        .saturation(1.4)
                        .opacity(0.8)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.35), value: halo)
            // The selected card is set apart by its glow only; the others by a shadow.
            .shadow(color: .black.opacity(halo ? 0 : 0.6), radius: cornerRadius * 1.4, y: cornerRadius * 0.6)
    }

    private var screen: some View {
        let scale = width / fullSize.width
        let fullUnit = min(fullSize.width / 15.2, fullSize.height / 8.2)
        return ZStack {
            DashboardBackground(theme: theme, unit: fullUnit)
            DashboardContent(theme: theme, dash: dash, unit: fullUnit, strings: strings)
                .padding(.vertical, fullUnit * 0.16)
        }
        .frame(width: fullSize.width, height: fullSize.height)
        .clipped()
        .compositingGroup()
        .scaleEffect(scale)
        .frame(width: width, height: fullSize.height * scale)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Dashboard background.
struct DashboardBackground: View {
    let theme: DashTheme
    let unit: CGFloat

    var body: some View {
        switch theme {
        case .dotMatrix: DotGridBackground(pitch: max(2, unit * 0.055))
        // Outside the display is the wheel body; the yellow warning lights only the LCD
        // itself, as in real cars.
        case .realistic: RealisticPalette.bezel
        case .modern, .game, .broadcast, .cluster: theme.background
        }
    }
}

/// Global frame of the carousel's centre card.
struct CardFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Draws the selected dashboard; shared by the root view and the carousel.
struct DashboardContent: View {
    let theme: DashTheme
    let dash: DashboardModel
    let unit: CGFloat
    let strings: Strings

    var body: some View {
        switch theme {
        case .modern: ModernDashboardView(dash: dash, unit: unit, strings: strings)
        case .dotMatrix: DotMatrixDashboardView(dash: dash, unit: unit)
        case .realistic: RealisticDashboardView(dash: dash, unit: unit)
        case .broadcast: BroadcastDashboardView(dash: dash, unit: unit)
        case .game: GameDashboardView(dash: dash, unit: unit)
        case .cluster: ClusterDashboardView(dash: dash, unit: unit)
        }
    }
}

/// Connection badge at the top right: a green dot and Hz while connected, otherwise a
/// tappable warning.
struct ConnectionBadge: View {
    let status: TelemetryClient.ConnectionStatus
    let hz: Int
    var isDemo = false
    let strings: Strings
    let unit: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: unit * 0.12) {
                if isDemo {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(Palette.accent)
                    Text(strings.demoBadge)
                    Image(systemName: "xmark")
                        .foregroundStyle(.white.opacity(0.5))
                } else if status == .receiving {
                    Circle().fill(Palette.live)
                        .frame(width: unit * 0.16, height: unit * 0.16)
                        .shadow(color: Palette.live.opacity(0.8), radius: unit * 0.1)
                    Text(verbatim: "\(strings.connected) · \(hz) Hz")
                        .contentTransition(.numericText())
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.accent)
                    Text(strings.notConnected)
                }
            }
            .font(Typeface.font(unit * 0.22, .heavy))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, unit * 0.3)
            .padding(.vertical, unit * 0.12)
            .background(Capsule().fill(Palette.deep.opacity(0.9)))
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
        // Tapping during the demo stops it.
        .allowsHitTesting(isDemo || status != .receiving)
        .animation(.spring(duration: 0.3), value: status == .receiving)
    }
}

/// The small card opened from the warning badge: five start lights, a short status and the
/// connection button.
struct ConnectionCard: View {
    let client: TelemetryClient
    let strings: Strings
    let unit: CGFloat
    let onOpenSetup: () -> Void
    let onClose: () -> Void

    private let cycle: Double = 7.5

    var body: some View {
        VStack(spacing: unit * 0.4) {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
                StartLightsView(litColumns: litColumns(phase: phase), unit: unit)
            }
            Text(title)
                .font(Typeface.font(unit * 0.4, .black))
                .foregroundStyle(.white)
                .tracking(2)
            Button(action: onOpenSetup) {
                Text(strings.setupButton)
                    .font(Typeface.font(unit * 0.3, .black))
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, unit * 0.6)
                    .padding(.vertical, unit * 0.18)
                    .background(Capsule().fill(Palette.accent))
            }
            .buttonStyle(PressScaleStyle())

            // Try everything without the game.
            Button {
                client.startDemo()
                onClose()
            } label: {
                Label(strings.demoStart, systemImage: "play.fill")
                    .font(Typeface.font(unit * 0.26, .black))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, unit * 0.5)
                    .padding(.vertical, unit * 0.14)
                    .background(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1.5))
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(unit * 0.6)
        .background(Palette.deep, in: RoundedRectangle(cornerRadius: unit * 0.4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: unit * 0.4, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(Typeface.font(unit * 0.28, .black))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(unit * 0.3)
            }
            .buttonStyle(PressScaleStyle())
        }
    }

    private func litColumns(phase: Double) -> Int {
        switch phase {
        case ..<5: return Int(phase) + 1
        case ..<6.5: return 5
        default: return 0
        }
    }

    private var title: String {
        switch client.status {
        case .idle: return strings.connectionOff
        case .listening:
            if let sent = client.formatWarning { return strings.formatMismatch(sent) }
            return strings.waitingForData
        case .receiving: return strings.connected
        case .failed(let message): return strings.failure(message)
        }
    }
}

extension DashboardModel {
    /// Ignition off: zero speed, neutral, cold tyres and brakes.
    static var cold: DashboardModel {
        var m = DashboardModel()
        m.tyreSurfaceTemps = [24, 24, 24, 24]; m.tyreInnerTemps = [24, 24, 24, 24]
        m.brakeTemps = [24, 24, 24, 24]; m.engineTemp = 24
        m.ersStoreEnergy = 4_000_000; m.ersHarvestLimitPerLap = 8_000_000
        m.fiaFlag = 0; m.is2026Regulations = true
        return m
    }

    static let warmUpDuration: TimeInterval = 9.0

    /// A calm stretch of driving played when a card is landed on, at a real car's pace: the
    /// engine comes to idle, the car pulls away in first, accelerates gear by gear, lifts,
    /// brakes while downshifting, stops and switches off. Every transition follows a smooth
    /// curve; RPM comes from the gear ratios.
    static func warmUp(at t: TimeInterval) -> DashboardModel {
        var m = DashboardModel.cold
        guard t > 0 else { return m }

        let idle = 4_200.0, shiftRPM = 12_000.0
        /// Speed of each gear at 12,000 RPM.
        let gearTop: [Double] = [0, 78, 112, 145, 178, 210, 242, 275, 310]

        func ease(_ x: Double) -> Double { let c = min(max(x, 0), 1); return c * c * (3 - 2 * c) }
        func phase(_ from: Double, _ to: Double) -> Double { ease((t - from) / (to - from)) }

        // Timeline (s): 0-1 idle, 1.2 pull away, 1.2-5.2 accelerate, 5.2-5.7 lift, 5.7-7.3
        // brake, 7.3-8.0 stop, 8.0-9.0 switch off.
        let launch = 1.2, lift = 5.2, brakeOn = 5.7, brakeOff = 7.3, stop = 8.0
        let accelerating = t >= launch && t < lift
        var speed: Double
        if t < launch {
            speed = 0
        } else if t < lift {
            speed = 250 * (1 - exp(-(t - launch) / 2.6))
        } else {
            let top = 250 * (1 - exp(-(lift - launch) / 2.6))
            let coast = top - 6 * phase(lift, brakeOn)
            let braked = coast - (coast - 28) * phase(brakeOn, brakeOff)
            speed = braked * (1 - phase(brakeOff, stop))
        }
        speed = max(speed, 0)

        var gear = 0
        if t >= launch - 0.2 && t < stop + 0.1 {
            gear = gearTop.firstIndex(where: { $0 > 0 && speed < $0 * 0.97 }) ?? 8
            gear = max(gear, 1)
        }

        let engineOn = ease(t / 0.9) * (1 - phase(stop + 0.2, warmUpDuration))
        var rpm = idle
        if gear > 0 && speed > 1 { rpm = max(idle, shiftRPM * speed / gearTop[gear]) }
        rpm *= engineOn

        m.speedKPH = Int(speed.rounded())
        m.gear = gear
        m.rpm = Int(rpm)
        // Rev lights fill from 9,000 RPM and stop short of the flashing shift point.
        let lights = min(max((rpm - 9_000) / (shiftRPM - 9_000), 0), 0.95)
        m.revLightsPercent = Int(lights * 100)
        let leds = Int(lights * 15)
        m.revLightsBits = leds <= 0 ? 0 : UInt16((1 << leds) - 1)

        m.throttle = Float(phase(launch - 0.3, launch + 0.4) * (1 - phase(lift, lift + 0.4)))
        m.brake = Float(0.75 * phase(brakeOn, brakeOn + 0.35) * (1 - phase(brakeOff - 0.5, brakeOff)))
        m.gLongitudinal = accelerating ? Float(1.1 * exp(-(t - launch) / 1.8)) : -Float(m.brake) * 4

        // Warming up: slow and moderate, then back to cold values at the end.
        let settle = 1 - phase(stop, warmUpDuration)
        let heat = phase(launch, stop) * settle
        let brakeHeat = phase(brakeOn, brakeOff) * settle
        m.tyreSurfaceTemps = [24 + Int(14 * heat), 24 + Int(14 * heat), 24 + Int(11 * heat), 24 + Int(11 * heat)]
        m.tyreInnerTemps = [24 + Int(9 * heat), 24 + Int(9 * heat), 24 + Int(7 * heat), 24 + Int(7 * heat)]
        m.brakeTemps = [24 + Int(260 * brakeHeat), 24 + Int(250 * brakeHeat), 24 + Int(330 * brakeHeat), 24 + Int(320 * brakeHeat)]
        m.engineTemp = 24 + Int(40 * heat)

        let deployed = 900_000 * phase(launch, lift)
        let harvested = 350_000 * phase(brakeOn, brakeOff)
        m.ersDeployedThisLap = Float(deployed * settle)
        m.ersHarvestedThisLap = Float(harvested * settle)
        m.ersStoreEnergy = Float(4_000_000 - (deployed - harvested) * settle)
        m.ersDeployMode = accelerating ? 2 : 0
        m.aeroAvailable = t > launch
        m.aeroStraightMode = t > 3.0 && t < lift
        return m
    }

    /// Sample values that look live, used by the onboarding.
    static var demo: DashboardModel {
        var m = DashboardModel()
        m.speedKPH = 274; m.gear = 7; m.rpm = 11_650; m.throttle = 1; m.brake = 0
        m.revLightsPercent = 68; m.revLightsBits = 0b0000_0011_1111_1111
        m.tyreSurfaceTemps = [96, 98, 92, 94]; m.tyreInnerTemps = [101, 103, 97, 99]
        m.brakeTemps = [420, 415, 480, 470]; m.engineTemp = 108
        m.ersStoreEnergy = 2_800_000; m.ersDeployMode = 2; m.fuelRemainingLaps = 3.2
        m.fiaFlag = 0; m.ersHarvestedThisLap = 1_600_000; m.ersHarvestLimitPerLap = 8_000_000
        m.ersDeployedThisLap = 900_000; m.aeroStraightMode = true; m.aeroAvailable = true
        m.overtakeAvailable = true; m.is2026Regulations = true
        m.currentLapTimeMS = 41_236; m.lastLapTimeMS = 88_412; m.deltaToCarInFrontMS = 1_240
        m.currentLapNum = 12; m.carPosition = 4
        m.sector1MS = 28_186; m.bestLapMS = 88_412; m.bestSectorMS = [28_186, 30_004, 30_222]
        m.deltaToBestMS = -184
        m.driverAhead = Rival(position: 3, name: "HAMILTON", red: 0.9, green: 0.2, blue: 0.2)
        m.player = Rival(position: 4, name: "ERSEVER", red: 0.25, green: 0.85, blue: 0.79)
        m.driverBehind = Rival(position: 5, name: "RUSSELL", red: 0.2, green: 0.6, blue: 0.9)
        return m
    }
}
