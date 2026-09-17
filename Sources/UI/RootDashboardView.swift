import SwiftUI
import StoreKit

/// The root view. The full-screen dashboard is a single "stage" view driven by one animated
/// value (`stage`: 0 = full screen, 1 = in place of the carousel card). Opening, SELECT and
/// pulling down all move this value; the view is never swapped between the two states, so
/// no frame of the transition breaks. When the stage settles exactly on the card (1.0) it
/// matches the card pixel for pixel and quietly hands over to it.
struct RootDashboardView: View {
    @EnvironmentObject private var client: TelemetryClient
    @AppStorage("dashTheme") private var themeID: String = DashTheme.realistic.rawValue
    /// An empty value means automatic: follow the phone's language.
    @AppStorage("appLanguage") private var languageID: String = ""
    /// The language setting used to have two states and locked to a language on first tap.
    /// The old value is cleared once so the app returns to automatic.
    @AppStorage("languagePreferenceReset") private var didResetLanguage = false
    @AppStorage("udpPort") private var udpPort: Int = 20777
    /// F1 26 by default; 2025 selects F1 25.
    @AppStorage("udpFormat") private var udpFormat: Int = 2026
    @AppStorage("didCompleteSetup") private var didCompleteSetup = false
    @AppStorage("webSession") private var sessionID: String = ""
    @AppStorage("shiftTorch") private var shiftTorch = false
    @AppStorage("didShowFlashWarning") private var didShowFlashWarning = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    /// Shown once; `-forceOnboarding YES` shows it again.
    @State private var showsOnboarding = !UserDefaults.standard.bool(forKey: "didCompleteOnboarding")
        || UserDefaults.standard.bool(forKey: "forceOnboarding")
    @State private var showsSetup = false
    /// The short splash on every launch; the onboarding has its own.
    @State private var showsSplash = true
    @State private var warnsAfterOnboarding = false
    /// Back button that appears at the top left when the full-screen dashboard is tapped.
    @State private var showsBack = false
    @State private var backHide: Task<Void, Never>?
    /// `-showSettings YES` and `-showLaps YES` open a screen at launch, for screenshots.
    @State private var showsSettings = UserDefaults.standard.bool(forKey: "showSettings")
    /// Can be opened directly with a launch argument, for screenshots.
    @State private var showsWebGuide = UserDefaults.standard.bool(forKey: "showWebGuide")
    @State private var showsLaps = UserDefaults.standard.bool(forKey: "showLaps")
    @State private var showsConnection = false

    /// Whether the stage is mounted (full screen or in transition). If not, the menu is
    /// showing.
    @State private var stageMounted = !UserDefaults.standard.bool(forKey: "skipHome") ? false : true
    /// 0 = full screen, 1 = in place of the carousel card.
    @State private var stage: CGFloat = UserDefaults.standard.bool(forKey: "skipHome") ? 0 : 1
    /// While the finger is pulling down.
    @State private var pulling = false
    @State private var settling = false
    @State private var cardFrame: CGRect = .zero
    /// Frozen data given to the dashboard during a transition, so redrawing 60 Hz telemetry
    /// does not drop animation frames.
    @State private var frozenDash: DashboardModel?
    /// Position of the full-screen pager; mirrors the dashboard selection.
    @State private var page: DashTheme? = DashTheme(rawValue: UserDefaults.standard.string(forKey: "dashTheme") ?? "") ?? .realistic

    @StateObject private var pairing = SitePairing()
    @StateObject private var server = LocalAnalysisServer()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @AppStorage("launchCount") private var launchCount = 0
    @AppStorage("lastReviewRequest") private var lastReviewRequest: Double = 0

    /// What the local analysis page serves: laps, their traces and the session.
    private var snapshot: SessionSnapshot {
        .init(laps: dash.completedLaps, traces: client.lapTraces, session: client.sessionInfo)
    }

    private var theme: DashTheme { DashTheme(rawValue: themeID) ?? .realistic }
    private var language: AppLanguage {
        AppLanguage.resolve(languageID)
    }
    private var strings: Strings { Strings(language: language) }
    private var dash: DashboardModel { client.dash }
    /// The data on screen: without a connection, the same cold values as the menu previews,
    /// so nothing jumps when opening or closing a dashboard.
    private var shownDash: DashboardModel { client.status == .receiving ? client.dash : .cold }
    private var inMenu: Bool { !stageMounted }
    private var fullscreen: Bool { stageMounted && stage == 0 }

    var body: some View {
        GeometryReader { geo in
            // The layout uses the whole screen; sizes scale with the shorter side.
            let unit = min(geo.size.width / 15.2, geo.size.height / 8.2)
            observed(screen(geo: geo, unit: unit))
        }
        // Full height vertically; horizontally it stays clear of the Dynamic Island.
        .ignoresSafeArea(edges: .vertical)
        // On the realistic dashboard the flash stays inside the display's own frame.
        .overlay {
            if fullscreen && theme != .realistic && theme != .broadcast && theme != .cluster {
                ShiftFlashOverlay(active: dash.shiftFlash).ignoresSafeArea()
            }
        }
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
    }

    // MARK: - Screen

    /// Layers and overlays.
    private func screen(geo: GeometryProxy, unit: CGFloat) -> some View {
        layers(geo: geo, unit: unit)
            .overlay { connectionOverlay(unit: unit) }
            .overlay { backOverlay(geo: geo, unit: unit) }
            .overlay { startLightsOverlay(unit: unit) }
            .overlay(alignment: .top) { sectorOverlay(unit: unit) }
            .overlay { sheets(unit: unit) }
    }

    @ViewBuilder
    private func sectorOverlay(unit: CGFloat) -> some View {
        Group {
            if let flash = dash.sectorFlash, client.status == .receiving, fullscreen {
                SectorFlashView(flash: flash, unit: unit)
                    .padding(.top, unit * 0.12)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: dash.sectorFlash)
    }

    /// Lifecycle and data observers.
    private func observed<V: View>(_ view: V) -> some View {
        view
            .onAppear {
                launchCount += 1
                if !didResetLanguage {
                    languageID = ""
                    didResetLanguage = true
                }
                page = theme
                // The analysis page is served from the phone; the site only learns its
                // address.
                server.snapshot = { snapshot }
                server.start()
                pairing.localAddress = { server.address(ip: client.localIP) }
                pairing.startWatching(sessionID: { sessionID })
                client.update(port: UInt16(udpPort))
                client.use(F1Game(format: PacketFormat(rawValue: UInt16(udpFormat)) ?? .f126))
                if !didCompleteSetup && !showsOnboarding { showsSetup = true }
                // `-startDemo YES` starts the demo drive at launch, for screenshots.
                if UserDefaults.standard.bool(forKey: "startDemo") { client.startDemo() }
            }
            .onChange(of: udpPort) { _, new in client.update(port: UInt16(new)) }
            .onChange(of: udpFormat) { _, new in
                client.use(F1Game(format: PacketFormat(rawValue: UInt16(new)) ?? .f126))
            }
            // Shift warning: the phone's flash blinks with the screen (enabled in
            // Settings).
            .onChange(of: dash.shiftFlash) { _, on in
                ShiftTorch.shared.update(active: on && fullscreen && client.status == .receiving,
                                         enabled: shiftTorch)
            }
            .onChange(of: shiftTorch) { _, enabled in
                ShiftTorch.shared.update(active: dash.shiftFlash && fullscreen, enabled: enabled)
            }
            .onChange(of: page) { _, new in
                if let new, new != theme { themeID = new.rawValue }
            }
            .onChange(of: themeID) { _, _ in
                if page != theme { page = theme }
            }
            // Ask for a rating at a good moment: a new personal best in a real
            // session, after a few launches, at most once every four months.
            .onChange(of: dash.bestLapMS) { old, new in
                guard old > 0, new > 0, new < old, !client.isDemoRunning,
                      dash.completedLaps.count >= 3, launchCount >= 3,
                      Date().timeIntervalSince1970 - lastReviewRequest > 120 * 24 * 3600
                else { return }
                lastReviewRequest = Date().timeIntervalSince1970
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    requestReview()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { server.start() }
            }
    }

    // MARK: - Layers

    /// Menu and stage; the menu stays underneath while the stage is not full screen.
    @ViewBuilder
    private func layers(geo: GeometryProxy, unit: CGFloat) -> some View {
        ZStack {
            if stage > 0 || inMenu { homeLayer(geo: geo, unit: unit) }
            if stageMounted {
                // In full screen the dashboard background extends past the safe area.
                DashboardBackground(theme: theme, unit: unit)
                    .ignoresSafeArea()
                    .opacity(1 - stage)
                stageView(geo: geo, unit: unit)
            }
        }
    }

    private func homeLayer(geo: GeometryProxy, unit: CGFloat) -> some View {
        let spring = Animation.spring(duration: 0.35, bounce: 0.1)
        return HomeView(client: client, strings: strings, unit: unit,
                        selectedTheme: Binding(get: { theme }, set: { themeID = $0.rawValue }),
                        onSelect: { present(geo) },
                        onLaps: { withAnimation(spring) { showsLaps = true } },
                        onSettings: { withAnimation(spring) { showsSettings = true } },
                        onOpenSetup: { withAnimation(spring) { showsSetup = true } },
                        hidesCentreCard: stageMounted,
                        frozenDash: frozenDash)
            .onPreferenceChange(CardFrameKey.self) { cardFrame = $0 }
            .opacity(min(1, stage * 2))
    }

    // MARK: - Stage

    /// The full-screen dashboard: the system pager moves between dashboards. The whole
    /// stage shrinks towards the card's frame as `stage` grows.
    private func stageView(geo: GeometryProxy, unit: CGFloat) -> some View {
        let t = stageTransform(geo)
        let corner = unit * 0.35
        // Pages are the full screen width including the safe area; content insets itself.
        // This keeps paging aligned with the screen edges.
        let lead = geo.safeAreaInsets.leading, trail = geo.safeAreaInsets.trailing
        let fullW = geo.size.width + lead + trail
        let live = frozenDash ?? shownDash
        return ZStack {
            if fullscreen && !settling {
                // In full screen the system pager moves between dashboards.
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(DashTheme.allCases) { item in
                            ZStack {
                                DashboardBackground(theme: item, unit: unit)
                                DashboardContent(theme: item, dash: live, unit: unit, strings: strings)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    // Dashboards with their own housing use the whole
                                    // screen; the others stay inside the safe area.
                                    .padding(.vertical, item == .cluster ? 0 : unit * 0.16)
                                    .padding(.leading, item == .realistic ? min(lead, unit * 0.34)
                                                     : (item == .cluster ? 0 : lead))
                                    .padding(.trailing, item == .realistic ? min(trail, unit * 0.34)
                                                      : (item == .cluster ? 0 : trail))
                            }
                            .frame(width: fullW, height: geo.size.height)
                            .id(item)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $page)
                .frame(width: fullW, height: geo.size.height)
                .ignoresSafeArea(.container, edges: .horizontal)
            } else {
                // A single page during transitions: drawn exactly like the carousel card.
                ZStack {
                    DashboardBackground(theme: theme, unit: unit)
                    DashboardContent(theme: theme, dash: live, unit: unit, strings: strings)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, unit * 0.16)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipShape(RoundedRectangle(cornerRadius: corner / t.scale, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: corner / t.scale, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.5 / t.scale)
                        .opacity(stage)
                }
            }
        }
        .frame(width: geo.size.width, height: geo.size.height)
        .scaleEffect(t.scale)
        .offset(t.offset)
        .simultaneousGesture(pullGesture(geo))
        .simultaneousGesture(TapGesture().onEnded { if fullscreen { revealBack() } })
    }

    /// Shows the back button; it hides itself after a few seconds without a touch.
    private func revealBack() {
        withAnimation(.easeOut(duration: 0.25)) { showsBack = true }
        backHide?.cancel()
        backHide = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.4)) { showsBack = false }
        }
    }

    @ViewBuilder
    private func backOverlay(geo: GeometryProxy, unit: CGFloat) -> some View {
        if fullscreen && showsBack && !settling && !showsSetup && !showsLaps && !showsSettings {
            Button {
                backHide?.cancel()
                showsBack = false
                showsConnection = false
                frozenDash = shownDash
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: unit * 0.32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: unit * 0.8, height: unit * 0.8)
                    .background(Circle().fill(Color.black.opacity(0.45)))
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(PressScaleStyle())
            // Translucent: it does not hide the dashboard but stays easy to see.
            .opacity(0.7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, unit * 0.3)
            .padding(.leading, unit * 0.5)
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
        }
    }

    /// Pulling this far places the stage exactly on the card.
    private func pullSpan(_ geo: GeometryProxy) -> CGFloat { geo.size.height * 0.35 }

    /// The stage's transform on screen: scale and offset towards the card's frame.
    private func stageTransform(_ geo: GeometryProxy) -> (scale: CGFloat, offset: CGSize) {
        let p = min(max(stage, 0), 1)
        let origin = geo.frame(in: .global).origin
        let target: CGRect = cardFrame == .zero
            ? CGRect(x: geo.size.width * 0.25, y: geo.size.height * 0.2,
                     width: geo.size.width * 0.5, height: geo.size.height * 0.5)
            : cardFrame.offsetBy(dx: -origin.x, dy: -origin.y)
        let endScale = target.width / geo.size.width
        let scale = 1 - p * (1 - endScale)
        return (scale, CGSize(width: (target.midX - geo.size.width / 2) * p,
                              height: (target.midY - geo.size.height / 2) * p))
    }

    /// Pull down: the stage follows the finger back to the card. Horizontal movement
    /// belongs to the pager; the first direction decides.
    private func pullGesture(_ geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard stageMounted, !settling else { return }
                let t = value.translation
                if !pulling {
                    guard abs(t.height) > abs(t.width) * 1.2, t.height > 0 else { return }
                    pulling = true
                    showsConnection = false
                    frozenDash = shownDash
                }
                stage = min(max(t.height / pullSpan(geo), 0), 1)
            }
            .onEnded { value in
                guard pulling else { return }
                pulling = false
                let projected = value.predictedEndTranslation.height / pullSpan(geo)
                if stage > 0.4 || projected > 1.1 { dismiss() } else { restore() }
            }
    }

    /// Menu to full screen: the stage takes the card's place and grows.
    private func present(_ geo: GeometryProxy) {
        guard !stageMounted else { return }
        var still = Transaction(); still.disablesAnimations = true
        withTransaction(still) { stage = 1; stageMounted = true; page = theme; frozenDash = shownDash }
        settling = true
        withAnimation(.spring(duration: 0.55, bounce: 0.12), completionCriteria: .logicallyComplete) {
            stage = 0
        } completion: {
            settling = false
            frozenDash = nil
        }
    }

    /// Full screen to menu: the stage settles on the card, then hands over to it.
    private func dismiss() {
        settling = true
        withAnimation(.spring(duration: 0.5, bounce: 0.1), completionCriteria: .logicallyComplete) {
            stage = 1
        } completion: {
            var still = Transaction(); still.disablesAnimations = true
            withTransaction(still) { stageMounted = false; stage = 1; frozenDash = nil }
            settling = false
        }
    }

    private func restore() {
        settling = true
        withAnimation(.spring(duration: 0.45, bounce: 0.15), completionCriteria: .logicallyComplete) {
            stage = 0
        } completion: {
            settling = false
            frozenDash = nil
        }
    }

    // MARK: - Overlays

    /// Laps, settings and connection screens; they slide up from the bottom.
    @ViewBuilder
    private func sheets(unit: CGFloat) -> some View {
        let spring = Animation.spring(duration: 0.35, bounce: 0.1)
        ZStack {
            if showsLaps {
                LapsView(laps: dash.completedLaps, bestSectorMS: dash.bestSectorMS,
                         strings: strings, unit: unit, server: server) {
                    withAnimation(spring) { showsLaps = false }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if showsSettings {
                SettingsView(languageID: $languageID, strings: strings, unit: unit,
                             isDemoRunning: client.isDemoRunning,
                             onDemo: { $0 ? client.startDemo() : client.stopDemo() },
                             onOpenConnection: { withAnimation(spring) { showsSetup = true } },
                             onOpenWebGuide: { withAnimation(spring) { showsWebGuide = true } },
                             onClose: { withAnimation(spring) { showsSettings = false } })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if showsWebGuide {
                WebGuideView(strings: strings, unit: unit, sessionID: $sessionID,
                             pairing: pairing,
                             localAddress: server.address(ip: client.localIP), server: server) {
                    withAnimation(spring) { showsWebGuide = false }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if (!didShowFlashWarning || warnsAfterOnboarding) && !showsOnboarding {
                FlashWarningView(strings: strings, unit: unit) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        didShowFlashWarning = true
                        warnsAfterOnboarding = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
            if showsSetup {
                SetupView(port: $udpPort, format: $udpFormat, mismatch: client.formatWarning,
                          strings: strings, localIP: client.localIP, unit: unit) {
                    didCompleteSetup = true
                    withAnimation(spring) { showsSetup = false }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if showsOnboarding {
                // The last scene also covers the connection address; the warning follows.
                OnboardingView(strings: strings, unit: unit, localIP: client.localIP, port: udpPort,
                               format: $udpFormat) {
                    didCompleteOnboarding = true
                    didCompleteSetup = true
                    // The onboarding started with its own splash; do not show another.
                    showsSplash = false
                    // The flashing lights warning before the menu: the onboarding's last
                    // step.
                    warnsAfterOnboarding = true
                    withAnimation(.easeOut(duration: 0.35)) { showsOnboarding = false }
                }
                .zIndex(20)
            }
            if showsSplash && !showsOnboarding {
                SplashView(strings: strings, unit: unit) { showsSplash = false }
                    .zIndex(30)
            }
        }
    }

    @ViewBuilder
    private func connectionOverlay(unit: CGFloat) -> some View {
        if fullscreen && !showsSetup && !showsLaps && !showsSettings {
            VStack(alignment: .trailing, spacing: unit * 0.15) {
                if client.status != .receiving || client.isDemoRunning {
                    ConnectionBadge(status: client.status, hz: client.packetsPerSecond,
                                    isDemo: client.isDemoRunning, strings: strings, unit: unit) {
                        if client.isDemoRunning { client.stopDemo(); return }
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) { showsConnection.toggle() }
                    }
                }
                if showsConnection {
                    ConnectionCard(client: client, strings: strings, unit: unit * 0.62,
                                   onOpenSetup: {
                                       showsConnection = false
                                       withAnimation(.spring(duration: 0.35, bounce: 0.1)) { showsSetup = true }
                                   },
                                   onClose: { withAnimation(.spring(duration: 0.3)) { showsConnection = false } })
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, unit * 0.3)
            .padding(.trailing, unit * 0.5)
            .transition(.opacity)
        }
    }

    /// Race start: lights come on as the game counts them, and a green "GO" shows briefly
    /// when they go out.
    @ViewBuilder
    private func startLightsOverlay(unit: CGFloat) -> some View {
        Group {
            if !fullscreen {
                EmptyView()
            } else if dash.startLights > 0 {
                StartLightsView(litColumns: dash.startLights, unit: unit)
                    .padding(unit * 0.4)
                    .background(Palette.deep.opacity(0.92), in: RoundedRectangle(cornerRadius: unit * 0.3))
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if dash.lightsOutDate != nil {
                Text(verbatim: "GO")
                    .font(.system(size: unit * 2.4, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.live)
                    .padding(unit * 0.5)
                    .background(Palette.deep.opacity(0.92), in: RoundedRectangle(cornerRadius: unit * 0.3))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.25), value: dash.startLights)
        .animation(.spring(duration: 0.3, bounce: 0.25), value: dash.lightsOutDate)
    }
}
