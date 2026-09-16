import SwiftUI

/// Acilis ekrani: temalar yatay bir karuselde yan yana durur, secili olan
/// onde ve buyuk. Kaydirma sistemin ScrollView'i ile yapilir (momentum,
/// lastik etkisi ve hizlanma sistemin kendi egrileri), gorunum gecisleri
/// scrollTransition ile parmaga baglidir. Liste, sonsuz donsun diye tema
/// dizisinin tekrarlarindan olusur ve bos anda ortaya geri alinir.
struct HomeView: View {
    /// Gozlenmez: onizlemeler 10 Hz ile TimelineView icinden okur, boylece
    /// bes pano birden her paketle yeniden cizilmez.
    let client: TelemetryClient
    let strings: Strings
    let unit: CGFloat
    @Binding var selectedTheme: DashTheme
    let onSelect: () -> Void
    let onLaps: () -> Void
    let onSettings: () -> Void
    let onOpenSetup: () -> Void
    /// Ortadaki kart gizli tutulur: tam ekran panonun sahnesi oraya oturur.
    var hidesCentreCard = false
    /// Gecis sirasinda onizlemeler bu sabit veriyle cizilir.
    var frozenDash: DashboardModel? = nil

    @State private var position: Int?
    /// Uzerine gelinen kartin isinma animasyonu: hangi kart, ne zaman basladi.
    @State private var warmUpIndex: Int?
    @State private var warmUpStart: Date = .distantPast
    @State private var showsConnection = false

    private let themes = DashTheme.allCases
    /// Tekrar sayisi tek: orta blok tam ortada kalir.
    private let repeats = 9
    private var itemCount: Int { themes.count * repeats }
    private var middleBase: Int { themes.count * (repeats / 2) }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let cardW = size.width * 0.50, cardH = cardW * size.height / size.width
            ZStack {
                StripedBackground()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, unit * 0.5)
                    Spacer(minLength: 0)
                    TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                        let live = client.status == .receiving
                        let elapsed = context.date.timeIntervalSince(warmUpStart)
                        carousel(size: size, cardW: cardW, cardH: cardH) { index in
                            if let frozenDash { return frozenDash }
                            if live { return client.dash }
                            // Baglanti yokken panolar soguk durur; yalnizca uzerine
                            // yeni gelinen kart bir kez canlanir.
                            guard index == warmUpIndex, elapsed < DashboardModel.warmUpDuration else { return .cold }
                            return .warmUp(at: elapsed)
                        }
                    }
                    .frame(height: cardH * 1.12)
                    titleAndDots
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
            }
            .onChange(of: position) { old, new in
                guard let new else { return }
                let theme = themes[new % themes.count]
                // Sonsuz donus icin ayni temanin baska kopyasina atlamak animasyon baslatmaz.
                if old.map({ themes[$0 % themes.count] }) != theme {
                    warmUpIndex = new
                    // Ilk kart acilis ekraninin arkasinda kalmasin: o bitince oynar.
                    warmUpStart = Date().addingTimeInterval(old == nil ? 2.3 : 0)
                } else if warmUpIndex == old {
                    warmUpIndex = new
                }
                if theme != selectedTheme { selectedTheme = theme }
            }
            .onChange(of: selectedTheme) { _, new in
                // Disaridan (tam ekran kaydirmasindan) gelen secim: en yakin tekrara git.
                guard let current = position, themes[current % themes.count] != new else { return }
                let target = nearestIndex(of: new, to: current)
                withAnimation(.spring(duration: 0.45, bounce: 0.1)) { position = target }
            }
        }
    }

    // MARK: Ust cubuk

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
                                strings: strings, unit: unit) {
                    if client.status != .receiving { showsConnection.toggle() }
                }
            }
        }
    }

    // MARK: Karusel

    private func carousel(size: CGSize, cardW: CGFloat, cardH: CGFloat,
                          dash: @escaping (Int) -> DashboardModel) -> some View {
        let sidePad = (size.width - cardW) / 2
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(0..<itemCount, id: \.self) { index in
                    let theme = themes[index % themes.count]
                    let isCentre = index == position
                    DashboardCard(theme: theme, dash: dash(index), strings: strings,
                                  fullSize: size, width: cardW, cornerRadius: unit * 0.35,
                                  highlighted: isCentre)
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
                                .scaleEffect(1 - abs(phase.value) * 0.26)
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

    /// Sonsuz donus: kenarlara yaklasinca, kimse bakmazken listenin ortasindaki
    /// esdeger karta atlanir. Kaydirma konumu ayni kartta kaldigi icin gorunmez.
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

    private var titleAndDots: some View {
        VStack(spacing: unit * 0.14) {
            Text(strings.themeTitle(selectedTheme))
                .font(Typeface.font(unit * 0.34, .black))
                .foregroundStyle(.white)
                .tracking(unit * 0.05)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: selectedTheme)
            HStack(spacing: unit * 0.12) {
                ForEach(themes) { theme in
                    Circle()
                        .fill(theme == selectedTheme ? Palette.accent : Color.white.opacity(0.25))
                        .frame(width: unit * 0.1, height: unit * 0.1)
                }
            }
            .animation(.spring(duration: 0.3), value: selectedTheme)
        }
    }

    // MARK: Alt cubuk

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

/// Kaydirma durunca listeyi ortalar. iOS 18'de kaydirma evresi dogrudan
/// bildirilir; iOS 17'de parmak birakildiktan kisa sure sonra denenir.
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
                        // Momentum bitene kadar bekle, sonra sessizce ortala.
                        try? await Task.sleep(for: .milliseconds(700))
                        guard !Task.isCancelled else { return }
                        recentre()
                    }
                }
            )
        }
    }
}

/// Dugmeye basinca hafifce kuculur; sistem dugmelerinin dokunusu gibi.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.2), value: configuration.isPressed)
    }
}

/// Bir temanin pano karti: pano tam ekran boyutunda cizilip `width`'e
/// olceklenir. Karusel kartlari ve tam ekran sahne ayni gorunumu kullanir,
/// boylece ikisi ust uste geldiginde piksel piksel ortusur.
struct DashboardCard: View {
    let theme: DashTheme
    let dash: DashboardModel
    let strings: Strings
    let fullSize: CGSize
    let width: CGFloat
    let cornerRadius: CGFloat
    var highlighted = false

    var body: some View {
        let scale = width / fullSize.width
        let fullUnit = min(fullSize.width / 15.2, fullSize.height / 8.2)
        ZStack {
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
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.6), radius: cornerRadius * 1.4, y: cornerRadius * 0.6)
    }
}

/// Tema zemini.
struct DashboardBackground: View {
    let theme: DashTheme
    let unit: CGFloat

    var body: some View {
        switch theme {
        case .dotMatrix: DotGridBackground(pitch: max(2, unit * 0.055))
        // Ekranin disinda kalan yer direksiyon govdesi; sari uyari sadece
        // LCD'nin kendisinde yanar, gercek araclardaki gibi.
        case .realistic: RealisticPalette.bezel
        case .modern, .game, .broadcast, .cluster: theme.background
        }
    }
}

/// Karuseldeki ortadaki kartin global cercevesi.
struct CardFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Tema secimine gore panoyu cizer; kok gorunum ve karusel ortak kullanir.
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

/// Sag ustteki baglanti rozeti: bagliyken yesil nokta ve Hz, degilken
/// dokunulabilir sari uyari ucgeni.
struct ConnectionBadge: View {
    let status: TelemetryClient.ConnectionStatus
    let hz: Int
    let strings: Strings
    let unit: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: unit * 0.12) {
                if status == .receiving {
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
        .allowsHitTesting(status != .receiving)
        .animation(.spring(duration: 0.3), value: status == .receiving)
    }
}

/// Uyari ucgenine dokununca acilan kucuk kart: bes baslangic isigi,
/// kisa durum yazisi ve kurulum dugmesi.
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
            if let game = client.mismatchedFormat { return strings.formatMismatch(game.label) }
            return strings.waitingForData
        case .receiving: return strings.connected
        case .failed(let message): return strings.failure(message)
        }
    }
}

extension DashboardModel {
    /// Kontak kapali: sifir hiz, bosta vites, soguk lastik ve frenler.
    static var cold: DashboardModel {
        var m = DashboardModel()
        m.tyreSurfaceTemps = [24, 24, 24, 24]; m.tyreInnerTemps = [24, 24, 24, 24]
        m.brakeTemps = [24, 24, 24, 24]; m.engineTemp = 24
        m.ersStoreEnergy = 4_000_000; m.ersHarvestLimitPerLap = 8_000_000
        m.fiaFlag = 0; m.is2026Regulations = true
        return m
    }

    static let warmUpDuration: TimeInterval = 3.2

    /// Karta ilk gelindiginde oynayan kisa tur: gaz, vites vites hizlanma,
    /// vites isiklari, frenleme ve yeniden soguk duruma inis.
    static func warmUp(at t: TimeInterval) -> DashboardModel {
        var m = DashboardModel.cold
        let d = warmUpDuration
        let p = min(max(t / d, 0), 1)
        // Hizlanma %0-60, frenleme %60-85, bosa alma %85-100.
        let speed: Double
        if p < 0.6 { speed = 305 * pow(p / 0.6, 0.8) }
        else if p < 0.85 { speed = 305 - 225 * ((p - 0.6) / 0.25) }
        else { speed = 80 * (1 - (p - 0.85) / 0.15) }
        let envelope = sin(.pi * p)
        let gearSpan = 40.0
        let gear = speed < 4 ? 0 : min(8, 1 + Int(speed / gearSpan))
        let inGear = speed < 4 ? 0 : (speed / gearSpan).truncatingRemainder(dividingBy: 1)

        m.speedKPH = Int(speed)
        m.gear = gear
        m.rpm = speed < 4 ? Int(4000 * envelope) : 6_500 + Int(inGear * 5_500)
        m.revLightsPercent = p < 0.6 ? Int(inGear * 100) : 0
        let lights = Int(Double(m.revLightsPercent) / 100 * 15)
        m.revLightsBits = lights <= 0 ? 0 : UInt16((1 << min(lights, 15)) - 1)
        m.throttle = p < 0.6 ? 1 : 0
        m.brake = p >= 0.6 && p < 0.85 ? 0.9 : 0
        m.gLongitudinal = Float(p < 0.6 ? 0.8 * envelope : -2.5 * envelope)
        m.gLateral = Float(sin(p * .pi * 3) * 0.8 * envelope)

        func warm(_ cold: Int, _ hot: Int) -> Int { cold + Int(Double(hot - cold) * envelope) }
        m.tyreSurfaceTemps = [warm(24, 96), warm(24, 98), warm(24, 92), warm(24, 94)]
        m.tyreInnerTemps = [warm(24, 101), warm(24, 103), warm(24, 97), warm(24, 99)]
        m.brakeTemps = [warm(24, 520), warm(24, 510), warm(24, 580), warm(24, 570)]
        m.engineTemp = warm(24, 108)

        m.ersStoreEnergy = Float(4_000_000 - 1_400_000 * envelope)
        m.ersDeployedThisLap = Float(1_400_000 * envelope)
        m.ersHarvestedThisLap = Float(p > 0.6 ? 1_200_000 * envelope : 0)
        m.ersDeployMode = 2
        m.aeroStraightMode = p > 0.2 && p < 0.6
        m.aeroAvailable = true
        m.overtakeAvailable = true
        m.overtakeActive = p > 0.35 && p < 0.55
        return m
    }

    /// Veri yokken karusel onizlemeleri icin canli gorunen ornek degerler.
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
