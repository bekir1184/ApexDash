import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var client: TelemetryClient

    private var dash: DashboardModel { client.dash }

    var body: some View {
        GeometryReader { geo in
            let unit = min(geo.size.width / 16, geo.size.height / 9)
            VStack(spacing: unit * 0.45) {
                RevLightsView(bits: dash.revLightsBits, flashing: dash.shiftFlash)
                    .frame(height: unit * 0.85)

                HStack(alignment: .center, spacing: unit * 0.6) {
                    leftColumn(unit: unit)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    gearBlock(unit: unit)

                    rightColumn(unit: unit)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(maxHeight: .infinity)

                PedalBarsView(throttle: dash.throttle, brake: dash.brake)
                    .frame(height: unit * 0.5)

                footer(unit: unit)
            }
            .padding(.horizontal, unit * 0.7)
            .padding(.vertical, unit * 0.5)
        }
        .background(Color.black)
        .overlay { if client.status != .receiving { waitingOverlay } }
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
    }

    // MARK: - Bloklar

    private func leftColumn(unit: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: unit * 0.25) {
            label("SPEED")
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "\(dash.speedKPH)")
                    .font(.system(size: unit * 1.9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("KM/H")
                    .font(.system(size: unit * 0.38, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            label("RPM")
            Text(verbatim: "\(dash.rpm)")
                .font(.system(size: unit * 0.85, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private func gearBlock(unit: CGFloat) -> some View {
        VStack(spacing: unit * 0.1) {
            Text(dash.gearLabel)
                .font(.system(size: unit * 4.6, weight: .black, design: .monospaced))
                .foregroundStyle(dash.shiftFlash ? Color(red: 0.36, green: 0.44, blue: 1.0) : .white)
                .shadow(color: dash.shiftFlash ? Color.blue.opacity(0.8) : .clear, radius: unit * 0.4)
                .animation(.easeOut(duration: 0.08), value: dash.shiftFlash)

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.08))
                .frame(height: unit * 0.16)
                .overlay(alignment: .leading) {
                    GeometryReader { g in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [.green, .yellow, .red],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * dash.rpmFraction)
                    }
                }
                .frame(width: unit * 4.2)
        }
    }

    private func rightColumn(unit: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: unit * 0.3) {
            badge(text: "OVERTAKE",
                  active: dash.overtakeActive,
                  ready: dash.overtakeAvailable,
                  color: Color(red: 0.99, green: 0.78, blue: 0.15),
                  unit: unit)
            badge(text: dash.aeroStraightMode ? "AERO Z" : "AERO X",
                  active: dash.aeroStraightMode,
                  ready: dash.aeroAvailable,
                  color: Color(red: 0.24, green: 0.78, blue: 1.0),
                  unit: unit)
            if dash.pitLimiterOn {
                badge(text: "PIT LIMITER", active: true, ready: true,
                      color: Color(red: 1.0, green: 0.35, blue: 0.35), unit: unit)
            }
        }
    }

    private func footer(unit: CGFloat) -> some View {
        HStack(spacing: unit * 0.6) {
            Text(verbatim: "F1 26 · UDP \(client.port.rawValue)")
            Spacer()
            Text(verbatim: "\(client.packetsPerSecond) Hz")
            Text(verbatim: client.localIP)
        }
        .font(.system(size: unit * 0.26, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.3))
    }

    private func badge(text: String, active: Bool, ready: Bool, color: Color, unit: CGFloat) -> some View {
        Text(text)
            .font(.system(size: unit * 0.42, weight: .black, design: .monospaced))
            .foregroundStyle(active ? .black : (ready ? color : Color.white.opacity(0.18)))
            .padding(.horizontal, unit * 0.35)
            .padding(.vertical, unit * 0.18)
            .background(
                RoundedRectangle(cornerRadius: unit * 0.18, style: .continuous)
                    .fill(active ? color : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: unit * 0.18, style: .continuous)
                    .stroke(ready ? color.opacity(0.7) : Color.white.opacity(0.1), lineWidth: 1.5)
            )
            .shadow(color: active ? color.opacity(0.7) : .clear, radius: unit * 0.25)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white.opacity(0.35))
            .tracking(2)
    }

    // MARK: - Veri yokken

    private var waitingOverlay: some View {
        VStack(spacing: 14) {
            Text(statusTitle)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 6) {
                Text("Oyunda: Ayarlar › Telemetri")
                Text("UDP Telemetry: On")
                Text("UDP Broadcast Mode: Off")
                Text("UDP IP Address: \(client.localIP)")
                Text(verbatim: "UDP Port: \(client.port.rawValue)")
                Text("UDP Send Rate: 60 Hz")
                Text("UDP Format: 2026")
            }
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.65))
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
