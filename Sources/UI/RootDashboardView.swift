import SwiftUI

/// Kok gorunum. Tam ekran pano bir "sahne" olarak tek bir gorunumdur ve
/// tek bir animasyonlu degerle (`stage`, 0 = tam ekran, 1 = karuseldeki
/// kartin yerinde) surulur. Menuye gecis, SEC ve asagi cekme hep bu degeri
/// hareket ettirir; iki durum arasinda gorunum degistirilmez, boylece gecis
/// hicbir karede kopmaz. Sahne kartin yerine tam oturdugunda (1.0) kartla
/// piksel piksel ayni oldugu icin yerini karta sessizce birakir.
struct RootDashboardView: View {
    @EnvironmentObject private var client: TelemetryClient
    @AppStorage("dashTheme") private var themeID: String = DashTheme.realistic.rawValue
    /// Bos deger "otomatik" demek: telefonun dili kullanilir.
    @AppStorage("appLanguage") private var languageID: String = ""
    /// Dil ayari once iki durumluydu ve ilk dokunusta bir dile kilitliyordu.
    /// Eski kayit bir kez temizlenir, boylece uygulama otomatige doner.
    @AppStorage("languagePreferenceReset") private var didResetLanguage = false
    @AppStorage("udpPort") private var udpPort: Int = 20777
    /// Varsayilan F1 26; F1 25 icin 2025 secilir.
    @AppStorage("udpFormat") private var udpFormat: Int = 2026
    @AppStorage("didCompleteSetup") private var didCompleteSetup = false
    @AppStorage("webSession") private var sessionID: String = ""
    @AppStorage("shiftTorch") private var shiftTorch = false
    @AppStorage("didShowFlashWarning") private var didShowFlashWarning = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    /// Tanitim bir kez gosterilir; `-forceOnboarding YES` ile yeniden acilir.
    @State private var showsOnboarding = !UserDefaults.standard.bool(forKey: "didCompleteOnboarding")
        || UserDefaults.standard.bool(forKey: "forceOnboarding")
    @State private var showsSetup = false
    /// Her acilista kisa acilis ekrani; tanitim varsa onun kendi acilisi yeter.
    @State private var showsSplash = true
    @State private var showsSettings = false
    /// Baslatma argumaniyla dogrudan acilabilir; ekran goruntusu almak icin.
    @State private var showsWebGuide = UserDefaults.standard.bool(forKey: "showWebGuide")
    @State private var showsLaps = false
    @State private var showsConnection = false

    /// Sahne takili mi (tam ekran ya da gecis halinde). Takili degilse menu.
    @State private var stageMounted = !UserDefaults.standard.bool(forKey: "skipHome") ? false : true
    /// 0 = tam ekran, 1 = karuseldeki kartin yerinde.
    @State private var stage: CGFloat = UserDefaults.standard.bool(forKey: "skipHome") ? 0 : 1
    /// Parmakla asagi cekme surerken.
    @State private var pulling = false
    @State private var settling = false
    @State private var cardFrame: CGRect = .zero
    /// Gecis boyunca panoya verilen sabit veri: 60 Hz telemetri yeniden
    /// cizimi animasyon karelerini bolmesin.
    @State private var frozenDash: DashboardModel?
    /// Tam ekran sayfalayicinin konumu; tema secimiyle esittir.
    @State private var page: DashTheme? = DashTheme(rawValue: UserDefaults.standard.string(forKey: "dashTheme") ?? "") ?? .realistic

    @StateObject private var uploader = SessionUploader()

    /// Siteye giden her sey: tur listesi, ayrintili tur izleri, pist bilgisi.
    private var uploadPayload: SessionUploader.Payload {
        .init(laps: dash.completedLaps, traces: client.lapTraces, session: client.sessionInfo)
    }

    private var theme: DashTheme { DashTheme(rawValue: themeID) ?? .realistic }
    private var language: AppLanguage {
        (LanguagePreference(rawValue: languageID) ?? .automatic).resolved
    }
    private var strings: Strings { Strings(language: language) }
    private var dash: DashboardModel { client.dash }
    /// Ekranda gosterilen veri: baglanti yokken menu onizlemeleriyle ayni
    /// ornek degerler, boylece buyutup geri donunce goruntu degismez.
    private var shownDash: DashboardModel { client.status == .receiving ? client.dash : .demo }
    private var inMenu: Bool { !stageMounted }
    private var fullscreen: Bool { stageMounted && stage == 0 }

    var body: some View {
        GeometryReader { geo in
            // Yerlesim ekranin tamamini kullanir; olculer kisa kenara gore olceklenir.
            let unit = min(geo.size.width / 15.2, geo.size.height / 8.2)
            observed(screen(geo: geo, unit: unit))
        }
        // Dikeyde tam ekran; yatayda Dynamic Island'in altina girilmez.
        .ignoresSafeArea(edges: .vertical)
        // Gercekci temada yanip sonme ekranin kendi cercevesi icinde kalir.
        .overlay {
            if fullscreen && theme != .realistic && theme != .broadcast && theme != .cluster {
                ShiftFlashOverlay(active: dash.shiftFlash).ignoresSafeArea()
            }
        }
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
    }

    // MARK: - Ekran

    /// Katmanlar ve ust bindirmeler.
    private func screen(geo: GeometryProxy, unit: CGFloat) -> some View {
        layers(geo: geo, unit: unit)
            .overlay { connectionOverlay(unit: unit) }
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

    /// Yasam dongusu ve veri gozlemcileri.
    private func observed<V: View>(_ view: V) -> some View {
        view
            .onAppear {
                if !didResetLanguage {
                    languageID = ""
                    didResetLanguage = true
                }
                page = theme
                uploader.startHeartbeat(payload: { uploadPayload }, sessionID: { sessionID })
                client.update(port: UInt16(udpPort))
                client.selectedFormat = PacketFormat(rawValue: UInt16(udpFormat)) ?? .f126
                if !didCompleteSetup && !showsOnboarding { showsSetup = true }
            }
            .onChange(of: udpPort) { _, new in client.update(port: UInt16(new)) }
            .onChange(of: udpFormat) { _, new in
                client.selectedFormat = PacketFormat(rawValue: UInt16(new)) ?? .f126
            }
            // Vites uyarisi: ekranla birlikte telefonun flasi (ayarlardan acilir).
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
            // Yeni tur tamamlandiginda site kendiliginden guncellenir.
            .onChange(of: client.lapTraces.count) { _, _ in
                guard !sessionID.isEmpty else { return }
                uploader.send(uploadPayload, sessionID: sessionID)
            }
    }

    // MARK: - Katmanlar

    /// Menu ve sahne; sahne tam ekran degilken menu altta durur.
    @ViewBuilder
    private func layers(geo: GeometryProxy, unit: CGFloat) -> some View {
        ZStack {
            if stage > 0 || inMenu { homeLayer(geo: geo, unit: unit) }
            if stageMounted {
                // Tam ekranda tema zemini guvenli alanin disina da tasar.
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

    // MARK: - Sahne

    /// Tam ekran pano: temalar arasinda sistemin sayfalayicisiyla gecilir.
    /// Butun sahne `stage` degerine gore kartin cercevesine dogru kuculur.
    private func stageView(geo: GeometryProxy, unit: CGFloat) -> some View {
        let t = stageTransform(geo)
        let corner = unit * 0.35
        // Sayfalar guvenli alan dahil tam ekran genisliginde; icerik kendi
        // icinde guvenli alana cekilir. Boylece sayfalama ekran kenariyla hizali.
        let lead = geo.safeAreaInsets.leading, trail = geo.safeAreaInsets.trailing
        let fullW = geo.size.width + lead + trail
        let live = frozenDash ?? shownDash
        return ZStack {
            if fullscreen && !settling {
                // Tam ekranda temalar arasinda sistemin sayfalayicisiyla gecilir.
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(DashTheme.allCases) { item in
                            ZStack {
                                DashboardBackground(theme: item, unit: unit)
                                DashboardContent(theme: item, dash: live, unit: unit, strings: strings)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    // Kendi govde cercevesi olan temalar ekranin
                                    // tamamini kullanir; digerleri guvenli alanda kalir.
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
                // Gecis halinde tek sayfa: karuseldeki kartla birebir ayni cizim.
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
    }

    /// Bu kadar cekilince sahne tam olarak kartin yerine oturur.
    private func pullSpan(_ geo: GeometryProxy) -> CGFloat { geo.size.height * 0.35 }

    /// Sahnenin ekrandaki donusumu: kartin cercevesine dogru olcek ve kayma.
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

    /// Asagi cekme: sahne parmakla birlikte kartin yerine iner. Yatay
    /// hareket sayfalayicinin; ilk yon karar verir.
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

    /// Menuden tam ekrana: sahne kartin ustune biner ve buyur.
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

    /// Tam ekrandan menuye: sahne kartin yerine oturur, sonra karta birakir.
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

    // MARK: - Ust katmanlar

    /// Turlar, ayarlar ve baglanti ekranlari; alttan gelir.
    @ViewBuilder
    private func sheets(unit: CGFloat) -> some View {
        let spring = Animation.spring(duration: 0.35, bounce: 0.1)
        ZStack {
            if showsLaps {
                LapsView(laps: dash.completedLaps, bestSectorMS: dash.bestSectorMS,
                         strings: strings, unit: unit, sessionID: $sessionID,
                         uploader: uploader, payload: { uploadPayload }) {
                    withAnimation(spring) { showsLaps = false }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if showsSettings {
                SettingsView(languageID: $languageID, strings: strings, unit: unit,
                             onOpenConnection: { withAnimation(spring) { showsSetup = true } },
                             onOpenWebGuide: { withAnimation(spring) { showsWebGuide = true } },
                             onClose: { withAnimation(spring) { showsSettings = false } })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if showsWebGuide {
                WebGuideView(strings: strings, unit: unit, sessionID: $sessionID,
                             uploader: uploader, payload: { uploadPayload }) {
                    withAnimation(spring) { showsWebGuide = false }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if !didShowFlashWarning && !showsOnboarding {
                FlashWarningView(strings: strings, unit: unit) {
                    withAnimation(.easeOut(duration: 0.3)) { didShowFlashWarning = true }
                }
                .transition(.opacity)
                .zIndex(10)
            }
            if showsSetup {
                SetupView(port: $udpPort, format: $udpFormat, mismatch: client.mismatchedFormat,
                          strings: strings, localIP: client.localIP, unit: unit) {
                    didCompleteSetup = true
                    withAnimation(spring) { showsSetup = false }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if showsOnboarding {
                // Son sahne isik uyarisini ve baglanti adresini de verir.
                OnboardingView(strings: strings, unit: unit, localIP: client.localIP, port: udpPort) {
                    didCompleteOnboarding = true
                    didShowFlashWarning = true
                    didCompleteSetup = true
                    // Tanitim kendi acilisiyla basladi; bitince tekrar gosterilmez.
                    showsSplash = false
                    showsOnboarding = false
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
                if client.status != .receiving {
                    ConnectionBadge(status: client.status, hz: client.packetsPerSecond,
                                    strings: strings, unit: unit) {
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

    /// Yaris basi: oyun isik sayisini gonderdikce yanar, sonunce kisa sure
    /// yesil bir "GO" gorunur.
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
