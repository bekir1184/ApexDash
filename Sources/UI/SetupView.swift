import SwiftUI

/// Ilk acilista ve bekleme ekranindaki dugmeyle acilan kurulum ekrani.
/// Garajda arac ayarlaniyormus hissi icin karbon zemin, pahli paneller ve
/// kirmizi marş dugmesi kullaniliyor.
struct SetupView: View {
    @Binding var port: Int
    let strings: Strings
    let localIP: String
    let unit: CGFloat
    let onDone: () -> Void

    @State private var portText: String = ""
    @FocusState private var portFocused: Bool

    private let red = Color(red: 0.85, green: 0.09, blue: 0.11)
    private let amber = Color(red: 0.97, green: 0.82, blue: 0.16)

    var body: some View {
        ZStack {
            CarbonBackground(pitch: max(6, unit * 0.22))
                .ignoresSafeArea()
                // Bos bir yere dokununca klavye kapanir.
                .contentShape(Rectangle())
                .onTapGesture { portFocused = false }

            VStack(alignment: .leading, spacing: unit * 0.28) {
                header
                HStack(alignment: .top, spacing: unit * 0.45) {
                    phonePlate
                    gamePlate
                }
                Text(verbatim: strings.broadcastNote)
                    .font(.system(size: unit * 0.23, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.32))
                    .fixedSize(horizontal: false, vertical: true)
                startButton
            }
            .padding(.horizontal, unit * 0.7)
            .padding(.vertical, unit * 0.4)
            .contentShape(Rectangle())
            .onTapGesture { portFocused = false }
        }
        .onAppear { portText = "\(port)" }
    }

    // MARK: - Baslik

    private var header: some View {
        HStack(alignment: .center, spacing: unit * 0.3) {
            Rectangle()
                .fill(red)
                .frame(width: unit * 0.14, height: unit * 0.5)
            Text(strings.setupTitle)
                .font(.system(size: unit * 0.5, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .tracking(6)
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
            Text(verbatim: "F1 26 · UDP")
                .font(.system(size: unit * 0.24, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    // MARK: - Telefon paneli

    private var phonePlate: some View {
        VStack(alignment: .leading, spacing: unit * 0.18) {
            plateLabel(strings.portLabel)

            HStack(spacing: unit * 0.18) {
                stepButton("−") { adjustPort(-1) }

                TextField("20777", text: $portText)
                    .keyboardType(.numberPad)
                    .focused($portFocused)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: unit * 0.6, weight: .black, design: .monospaced))
                    .foregroundStyle(amber)
                    .padding(.vertical, unit * 0.12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: unit * 0.12, style: .continuous)
                            .fill(Color.black.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: unit * 0.12, style: .continuous)
                            .stroke(portFocused ? amber.opacity(0.8) : Color.white.opacity(0.15),
                                    lineWidth: 1.5)
                    )
                    .onChange(of: portText) { _, new in
                        let digits = String(new.filter(\.isNumber).prefix(5))
                        if digits != new { portText = digits }
                        if let value = Int(digits), (1024...65535).contains(value) { port = value }
                    }

                stepButton("+") { adjustPort(1) }

                if portFocused {
                    Button { portFocused = false } label: {
                        Text(verbatim: "OK")
                            .font(.system(size: unit * 0.28, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, unit * 0.26)
                            .padding(.vertical, unit * 0.16)
                            .background(Capsule().fill(amber))
                    }
                    .buttonStyle(.plain)
                }
            }

            plateLabel(strings.phoneAddress)
            Text(verbatim: localIP)
                .font(.system(size: unit * 0.52, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.vertical, unit * 0.1)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: unit * 0.12, style: .continuous)
                        .fill(Color.black.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: unit * 0.12, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                )
        }
        .padding(unit * 0.34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .carbonPlate(unit: unit)
    }

    private func adjustPort(_ delta: Int) {
        portFocused = false
        let value = min(max(port + delta, 1024), 65535)
        port = value
        portText = "\(value)"
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: symbol)
                .font(.system(size: unit * 0.42, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: unit * 0.62, height: unit * 0.62)
                .background(
                    Circle().fill(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.1)],
                                                 startPoint: .top, endPoint: .bottom))
                )
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Oyun paneli

    private var gamePlate: some View {
        VStack(alignment: .leading, spacing: unit * 0.1) {
            plateLabel(strings.gameSettings)
            row("UDP Telemetry", "On")
            row("UDP Broadcast Mode", "Off")
            row("UDP IP Address", localIP)
            row("UDP Port", "\(port)")
            row("UDP Send Rate", "60 Hz")
            row("UDP Format", "2026")
            row("Your Telemetry", "Public")
        }
        .padding(unit * 0.34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .carbonPlate(unit: unit)
    }

    private func row(_ name: String, _ value: String) -> some View {
        HStack(spacing: unit * 0.16) {
            Text(verbatim: name)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
            Text(verbatim: value)
                .foregroundStyle(amber)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(.system(size: unit * 0.25, weight: .heavy, design: .monospaced))
    }

    private func plateLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: unit * 0.23, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white.opacity(0.4))
            .tracking(2)
    }

    // MARK: - Mars dugmesi

    private var startButton: some View {
        Button(action: onDone) {
            Text(strings.startButton)
                .font(.system(size: unit * 0.38, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .tracking(4)
                .frame(maxWidth: .infinity)
                .padding(.vertical, unit * 0.22)
                .background(
                    Capsule().fill(
                        LinearGradient(colors: [red.opacity(0.95), Color(red: 0.5, green: 0.03, blue: 0.05)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                )
                .overlay(
                    Capsule().stroke(
                        LinearGradient(colors: [Color.white.opacity(0.5), Color.black.opacity(0.6)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: unit * 0.05
                    )
                )
                .shadow(color: red.opacity(0.55), radius: unit * 0.3)
        }
        .buttonStyle(.plain)
    }
}
