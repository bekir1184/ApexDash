import SwiftUI

struct RootDashboardView: View {
    @EnvironmentObject private var client: TelemetryClient
    @AppStorage("dashTheme") private var themeID: String = DashTheme.dotMatrix.rawValue
    @AppStorage("appLanguage") private var languageID: String = AppLanguage.systemDefault.rawValue
    @AppStorage("udpPort") private var udpPort: Int = 20777
    @AppStorage("didCompleteSetup") private var didCompleteSetup = false
    @State private var showsSetup = false
    @State private var showsLaps = false
    @AppStorage("webSession") private var sessionID: String = ""
    @StateObject private var uploader = SessionUploader()
    @State private var showsThemePicker = false
    @State private var hideTask: Task<Void, Never>?

    private var theme: DashTheme { DashTheme(rawValue: themeID) ?? .dotMatrix }
    private var language: AppLanguage { AppLanguage(rawValue: languageID) ?? .systemDefault }
    private var strings: Strings { Strings(language: language) }
    private var dash: DashboardModel { client.dash }

    var body: some View {
        GeometryReader { geo in
            // Yerlesim ekranin tamamini kullanir; olculer kisa kenara gore olceklenir.
            let unit = min(geo.size.width / 15.2, geo.size.height / 8.2)
            ZStack(alignment: .bottom) {
                themeBackground(unit: unit)
                    .ignoresSafeArea()

                content(unit: unit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, unit * 0.16)
                    // Gercekci temada govde cercevesi yatay guvenli alanin
                    // disina, Dynamic Island bandinin uzerine tasar; orada
                    // sadece isiklar var, yazi yok.
                    // Govde guvenli alanin disina tasar ama cihaz kenarina
                    // dayanmaz: dis pah her yandan gorunsun diye biraz icerde kalir.
                    .padding(.horizontal, theme == .realistic
                             ? -max(max(geo.safeAreaInsets.leading, geo.safeAreaInsets.trailing) - unit * 0.34, 0)
                             : 0)

                if showsThemePicker {
                    VStack(spacing: unit * 0.15) {
                        themePicker(unit: unit)
                        footer(unit: unit)
                    }
                    .padding(.horizontal, unit * 0.6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .top) {
                if let flash = dash.sectorFlash, client.status == .receiving {
                    SectorFlashView(flash: flash, unit: unit)
                        .padding(.top, unit * 1.2)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dash.sectorFlash)
            .overlay {
                if client.status != .receiving && !showsSetup && !showsLaps {
                    waitingOverlay(unit: unit)
                }
            }
            .overlay {
                if showsLaps {
                    LapsView(laps: dash.completedLaps,
                             bestSectorMS: dash.bestSectorMS,
                             strings: strings,
                             unit: unit,
                             sessionID: $sessionID,
                             uploader: uploader) { showsLaps = false }
                    .transition(.opacity)
                }
            }
            .overlay {
                if showsSetup {
                    SetupView(port: $udpPort,
                              strings: strings,
                              localIP: client.localIP,
                              unit: unit) {
                        didCompleteSetup = true
                        showsSetup = false
                    }
                    .transition(.opacity)
                }
            }
            .onAppear {
                uploader.startHeartbeat(laps: { dash.completedLaps },
                                        sessionID: { sessionID })
                client.update(port: UInt16(udpPort))
                if !didCompleteSetup { showsSetup = true }
            }
            .onChange(of: udpPort) { _, new in
                client.update(port: UInt16(new))
            }
            // Yeni tur tamamlandiginda site kendiliginden guncellenir.
            .onChange(of: dash.completedLaps.count) { _, _ in
                guard !sessionID.isEmpty else { return }
                uploader.send(laps: dash.completedLaps, sessionID: sessionID)
            }
            .contentShape(Rectangle())
            .onTapGesture { revealPicker() }
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        themeID = theme.next.rawValue
                        revealPicker()
                    }
            )
        }
        // Dikeyde tam ekran; yatayda Dynamic Island'in altina girilmez.
        .ignoresSafeArea(edges: .vertical)
        // Gercekci temada yanip sonme ekranin kendi cercevesi icinde kalir.
        .overlay {
            if theme != .realistic {
                ShiftFlashOverlay(active: dash.shiftFlash).ignoresSafeArea()
            }
        }
        
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
    }

    /// Tema zemini ekranin tamamini kaplar; nokta dokusu Dynamic Island'in
    /// altinda da devam ettigi icin panel her yerde ayni gorunur.
    @ViewBuilder
    private func themeBackground(unit: CGFloat) -> some View {
        switch theme {
        case .dotMatrix: DotGridBackground(pitch: max(2, unit * 0.055))
        // Ekranin disinda kalan yer direksiyon govdesi; sarı uyari sadece
        // LCD'nin kendisinde yanar, gercek araclardaki gibi.
        case .realistic: RealisticPalette.bezel
        case .modern, .game: theme.background
        }
    }

    @ViewBuilder
    private func content(unit: CGFloat) -> some View {
        switch theme {
        case .modern: ModernDashboardView(dash: dash, unit: unit, strings: strings)
        case .dotMatrix: DotMatrixDashboardView(dash: dash, unit: unit)
        case .realistic: RealisticDashboardView(dash: dash, unit: unit)
        case .game: GameDashboardView(dash: dash, unit: unit)
        }
    }

    private func themePicker(unit: CGFloat) -> some View {
        HStack(spacing: unit * 0.2) {
            ForEach(DashTheme.allCases) { option in
                Button {
                    themeID = option.rawValue
                    revealPicker()
                } label: {
                    Text(strings.themeTitle(option))
                        .font(.system(size: unit * 0.28, weight: .black, design: .monospaced))
                        .foregroundStyle(option == theme ? .black : .white.opacity(0.7))
                        .padding(.horizontal, unit * 0.3)
                        .padding(.vertical, unit * 0.14)
                        .background(
                            Capsule().fill(option == theme ? Color.white : Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }

            Button {
                withAnimation(.easeOut(duration: 0.2)) { showsLaps = true }
            } label: {
                Text(strings.lapsButton)
                    .font(.system(size: unit * 0.28, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, unit * 0.3)
                    .padding(.vertical, unit * 0.14)
                    .background(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 1.5))
            }
            .buttonStyle(.plain)

            Button {
                languageID = language.next.rawValue
                revealPicker()
            } label: {
                Text(verbatim: language.label)
                    .font(.system(size: unit * 0.28, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, unit * 0.3)
                    .padding(.vertical, unit * 0.14)
                    .background(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        }
        .padding(unit * 0.14)
        .background(Capsule().fill(.black.opacity(0.85)))
        .padding(.bottom, unit * 0.25)
    }

    private func revealPicker() {
        withAnimation(.easeOut(duration: 0.18)) { showsThemePicker = true }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.25)) { showsThemePicker = false }
        }
    }

    private func footer(unit: CGFloat) -> some View {
        HStack {
            Text(verbatim: "F1 26 · UDP \(client.port.rawValue)")
            Spacer()
            if !sessionID.isEmpty {
                Text(verbatim: uploader.lastError == nil ? "WEB \(sessionID)" : "WEB ?")
                    .foregroundStyle(uploader.lastError == nil
                                     ? Color(red: 0.24, green: 0.92, blue: 0.35).opacity(0.7)
                                     : Color(red: 1, green: 0.4, blue: 0.35).opacity(0.8))
            }
            Text(verbatim: "\(client.packetsPerSecond) Hz")
            Text(verbatim: client.localIP)
        }
        .font(.system(size: unit * 0.22, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.22))
    }

    private func waitingOverlay(unit: CGFloat) -> some View {
        WaitingView(title: statusTitle,
                    strings: strings,
                    localIP: client.localIP,
                    port: client.port.rawValue,
                    unit: unit,
                    previousIP: client.previousIP) {
            withAnimation(.easeOut(duration: 0.2)) { showsSetup = true }
        }
    }

    private var statusTitle: String {
        switch client.status {
        case .idle: return strings.connectionOff
        case .listening: return strings.waitingForData
        case .receiving: return ""
        case .failed(let message): return strings.failure(message)
        }
    }
}
