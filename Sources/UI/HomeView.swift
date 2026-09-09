import SwiftUI

/// Acilis ekrani: temalar yatay bir karuselde yan yana durur, secili olan
/// onde ve buyuk. Sola saga kaydirilir, sonsuz doner; SEC ile tam ekrana gecilir.
struct HomeView: View {
    /// Gozlenmez: onizlemeler 10 Hz ile TimelineView icinden okur, boylece
    /// bes pano birden her paketle yeniden cizilmez.
    let client: TelemetryClient
    let strings: Strings
    let unit: CGFloat
    @Binding var selectedTheme: DashTheme
    let onSelect: () -> Void
    let onLaps: () -> Void
    let onLanguage: () -> Void
    let onOpenSetup: () -> Void
    let languageLabel: String

    @State private var drag: CGFloat = 0
    @State private var showsConnection = false

    private let themes = DashTheme.allCases

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let cardW = size.width * 0.50, cardH = cardW / 2.16
            ZStack {
                background

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, unit * 0.5)
                    Spacer(minLength: 0)
                    TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                        let live = client.status == .receiving
                        let dash = live ? client.dash : DashboardModel.demo
                        carousel(in: size, dash: dash)
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
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showsConnection)
        }
    }

    // MARK: Zemin

    private var background: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.08)
            // Arkadaki dairesel yazi: resimdeki gibi hafif, dekoratif.
            CircularText(text: "F1 26 TELEMETRY · STEERING WHEEL DISPLAY · ", radius: unit * 3.1)
                .font(.system(size: unit * 0.42, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.05))
                .offset(y: -unit * 0.4)
            RadialGradient(colors: [Color(red: 0.16, green: 0.55, blue: 0.62).opacity(0.28), .clear],
                           center: .center, startRadius: 0, endRadius: unit * 6)
        }
        .ignoresSafeArea()
    }

    // MARK: Ust cubuk

    private var header: some View {
        HStack {
            HStack(spacing: unit * 0.16) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: unit * 0.5, weight: .black))
                    .foregroundStyle(Color(red: 0.25, green: 0.85, blue: 0.79))
                Text(verbatim: "F1")
                    .font(.system(size: unit * 0.52, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                + Text(verbatim: "DASH")
                    .font(.system(size: unit * 0.52, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.25, green: 0.85, blue: 0.79))
            }
            .tracking(unit * 0.06)

            Spacer()

            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                ConnectionBadge(status: client.status, hz: client.packetsPerSecond,
                                strings: strings, unit: unit) {
                    showsConnection.toggle()
                }
            }
        }
    }

    // MARK: Karusel

    private func carousel(in size: CGSize, dash: DashboardModel) -> some View {
        let cardW = size.width * 0.50, cardH = cardW / 2.16
        let step = cardW * 0.66                      // kartlar arasi mesafe: yandakiler kenardan gorunur
        let count = themes.count
        let current = themes.firstIndex(of: selectedTheme) ?? 0
        let progress = -drag / step                  // surukleme ile ara konum
        return ZStack {
            ForEach(-2...2, id: \.self) { slot in
                let index = ((current + slot) % count + count) % count
                let theme = themes[index]
                let rel = CGFloat(slot) - progress   // 0 = merkez
                let scale = max(0.5, 1 - abs(rel) * 0.26)
                let z = 10 - abs(rel)
                card(theme: theme, dash: dash, width: cardW, height: cardH, size: size)
                    .scaleEffect(scale)
                    .opacity(max(0.2, 1 - abs(rel) * 0.45))
                    .offset(x: rel * step)
                    .zIndex(Double(z))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { drag = $0.translation.width }
                .onEnded { value in
                    let projected = value.predictedEndTranslation.width
                    var move = 0
                    if projected < -step * 0.35 { move = 1 } else if projected > step * 0.35 { move = -1 }
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        if move != 0 {
                            let next = ((current + move) % count + count) % count
                            selectedTheme = themes[next]
                        }
                        drag = 0
                    }
                }
        )
    }

    private var titleAndDots: some View {
        VStack(spacing: unit * 0.14) {
            Text(strings.themeTitle(selectedTheme))
                .font(.system(size: unit * 0.34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tracking(unit * 0.05)
            HStack(spacing: unit * 0.12) {
                ForEach(themes) { theme in
                    Circle()
                        .fill(theme == selectedTheme ? Color.white : Color.white.opacity(0.25))
                        .frame(width: unit * 0.1, height: unit * 0.1)
                }
            }
        }
    }

    /// Bir temanin canli onizlemesi: pano tam ekran boyutunda cizilip karta
    /// olceklenir, boylece tam ekrandaki yerlesimin aynisi gorunur.
    private func card(theme: DashTheme, dash: DashboardModel, width: CGFloat, height: CGFloat,
                      size: CGSize) -> some View {
        let full = CGSize(width: size.width, height: size.width / 2.16)
        let scale = width / full.width
        let fullUnit = min(full.width / 15.2, full.height / 8.2)
        return ZStack {
            themeBackground(theme, unit: fullUnit)
            DashboardContent(theme: theme, dash: dash, unit: fullUnit, strings: strings)
                .padding(.vertical, fullUnit * 0.16)
        }
        .frame(width: full.width, height: full.height)
        .clipped()
        .compositingGroup()
        .scaleEffect(scale)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: unit * 0.35, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.35, style: .continuous)
                .stroke(Color.white.opacity(theme == selectedTheme ? 0.35 : 0.12), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.6), radius: unit * 0.5, y: unit * 0.2)
    }

    @ViewBuilder
    private func themeBackground(_ theme: DashTheme, unit: CGFloat) -> some View {
        switch theme {
        case .dotMatrix: DotGridBackground(pitch: max(2, unit * 0.055))
        case .realistic: RealisticPalette.bezel
        case .modern, .game, .broadcast: theme.background
        }
    }

    // MARK: Alt cubuk

    private var footer: some View {
        HStack {
            pill(strings.lapsButton, filled: false, action: onLaps)
            Spacer()
            Button(action: onSelect) {
                Text(strings.selectButton)
                    .font(.system(size: unit * 0.32, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .tracking(unit * 0.05)
                    .padding(.horizontal, unit * 1.1)
                    .padding(.vertical, unit * 0.2)
                    .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)
            Spacer()
            pill(languageLabel, filled: false, action: onLanguage)
        }
    }

    private func pill(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: unit * 0.24, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, unit * 0.36)
                .padding(.vertical, unit * 0.14)
                .background(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
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
                    Circle().fill(Color(red: 0.24, green: 0.92, blue: 0.35))
                        .frame(width: unit * 0.16, height: unit * 0.16)
                        .shadow(color: Color(red: 0.24, green: 0.92, blue: 0.35).opacity(0.8), radius: unit * 0.1)
                    Text(verbatim: "\(strings.connected) · \(hz) Hz")
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(red: 0.97, green: 0.78, blue: 0.15))
                    Text(strings.notConnected)
                }
            }
            .font(.system(size: unit * 0.22, weight: .heavy, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, unit * 0.3)
            .padding(.vertical, unit * 0.12)
            .background(Capsule().fill(.black.opacity(0.5)))
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Uyari ucgenine dokununca acilan kucuk kart: bes baslangic isigi,
/// durum ve oyundaki ayar tarifi ile kurulum dugmesi.
struct ConnectionCard: View {
    let client: TelemetryClient
    let strings: Strings
    let unit: CGFloat
    let onOpenSetup: () -> Void
    let onClose: () -> Void

    var body: some View {
        WaitingView(title: title,
                    strings: strings,
                    localIP: client.localIP,
                    port: client.port.rawValue,
                    unit: unit,
                    previousIP: client.previousIP,
                    onOpenSetup: onOpenSetup)
            .overlay(alignment: .topTrailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: unit * 0.3, weight: .black))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(unit * 0.3)
                }
                .buttonStyle(.plain)
            }
    }

    private var title: String {
        switch client.status {
        case .idle: return strings.connectionOff
        case .listening: return strings.waitingForData
        case .receiving: return strings.connected
        case .failed(let message): return strings.failure(message)
        }
    }
}

/// Bir cember boyunca dizilmis yazi (dekoratif zemin icin).
struct CircularText: View {
    let text: String
    let radius: CGFloat

    var body: some View {
        let chars = Array(text)
        let step = 2 * Double.pi / Double(chars.count)
        ZStack {
            ForEach(chars.indices, id: \.self) { i in
                let angle = Double(i) * step
                Text(String(chars[i]))
                    .rotationEffect(.radians(angle + .pi / 2))
                    .offset(x: radius * CGFloat(cos(angle)), y: radius * CGFloat(sin(angle)))
            }
        }
    }
}

extension DashboardModel {
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
