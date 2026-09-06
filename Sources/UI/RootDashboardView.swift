import SwiftUI

struct RootDashboardView: View {
    @EnvironmentObject private var client: TelemetryClient
    @AppStorage("dashTheme") private var themeID: String = DashTheme.modern.rawValue
    @State private var showsThemePicker = false
    @State private var hideTask: Task<Void, Never>?

    private var theme: DashTheme { DashTheme(rawValue: themeID) ?? .modern }
    private var dash: DashboardModel { client.dash }

    var body: some View {
        GeometryReader { geo in
            let unit = min(geo.size.width / 16, geo.size.height / 9)
            ZStack(alignment: .bottom) {
                content(unit: unit)
                    .padding(.horizontal, unit * 0.5)
                    .padding(.vertical, unit * 0.4)

                if showsThemePicker {
                    themePicker(unit: unit)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    footer(unit: unit)
                        .padding(.horizontal, unit * 0.6)
                        .padding(.bottom, unit * 0.1)
                }
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
        .background(Color.black)
        .overlay { if client.status != .receiving { waitingOverlay } }
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
    }

    @ViewBuilder
    private func content(unit: CGFloat) -> some View {
        switch theme {
        case .modern: ModernDashboardView(dash: dash, unit: unit)
        case .dotMatrix: DotMatrixDashboardView(dash: dash, unit: unit)
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
                    Text(option.title)
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
            Text(verbatim: "\(client.packetsPerSecond) Hz")
            Text(verbatim: client.localIP)
        }
        .font(.system(size: unit * 0.22, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.28))
    }

    private var waitingOverlay: some View {
        VStack(spacing: 14) {
            Text(statusTitle)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 6) {
                Text("Oyunda: Ayarlar › Telemetri")
                Text("UDP Telemetry: On")
                Text("UDP Broadcast Mode: Off")
                Text(verbatim: "UDP IP Address: \(client.localIP)")
                Text(verbatim: "UDP Port: \(client.port.rawValue)")
                Text("UDP Send Rate: 60 Hz")
                Text("UDP Format: 2026")
            }
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.65))
            Text("Tasarimi degistirmek icin ekrana dokun veya yana kaydir")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(28)
        .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var statusTitle: String {
        switch client.status {
        case .idle: return "BAGLANTI KAPALI"
        case .listening: return "VERI BEKLENIYOR"
        case .receiving: return ""
        case .failed(let message): return "HATA: \(message)"
        }
    }
}
