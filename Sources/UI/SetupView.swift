import SwiftUI

/// Ilk acilista ve bekleme ekranindaki dugmeyle acilan kurulum ekrani.
/// Port hem burada dinlenir hem de oyuna ayni deger girilir; telefonun IP
/// adresi de buradan kopyalanir.
struct SetupView: View {
    @Binding var port: Int
    let strings: Strings
    let localIP: String
    let unit: CGFloat
    let onDone: () -> Void

    @State private var portText: String = ""
    @FocusState private var portFocused: Bool

    private let accent = Color(red: 0.95, green: 0.85, blue: 0.15)

    var body: some View {
        VStack(alignment: .leading, spacing: unit * 0.26) {
            Text(strings.setupTitle)
                .font(.system(size: unit * 0.5, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .tracking(4)

            Text(verbatim: strings.setupIntro)
                .font(.system(size: unit * 0.3, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: unit * 0.5) {
                phonePanel
                gamePanel
            }

            Text(verbatim: strings.broadcastNote)
                .font(.system(size: unit * 0.24, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onDone) {
                Text(strings.startButton)
                    .font(.system(size: unit * 0.36, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, unit * 0.2)
                    .background(Capsule().fill(accent))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, unit * 0.7)
        .padding(.vertical, unit * 0.45)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .contentShape(Rectangle())
        .onTapGesture { portFocused = false }
        .onAppear { portText = "\(port)" }
    }

    // MARK: - Telefon tarafi

    private var phonePanel: some View {
        VStack(alignment: .leading, spacing: unit * 0.25) {
            label(strings.portLabel)
            HStack(spacing: unit * 0.18) {
                TextField("20777", text: $portText)
                    .keyboardType(.numberPad)
                    .focused($portFocused)
                    .textFieldStyle(.plain)
                .font(.system(size: unit * 0.6, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, unit * 0.25)
                .padding(.vertical, unit * 0.12)
                .background(
                    RoundedRectangle(cornerRadius: unit * 0.14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                    .onChange(of: portText) { _, new in
                        let digits = String(new.filter(\.isNumber).prefix(5))
                        if digits != new { portText = digits }
                        if let value = Int(digits), (1024...65535).contains(value) { port = value }
                    }

                stepButton("−") { adjustPort(-1) }
                stepButton("+") { adjustPort(1) }

                if portFocused {
                    Button { portFocused = false } label: {
                        Text(verbatim: "OK")
                            .font(.system(size: unit * 0.26, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, unit * 0.24)
                            .padding(.vertical, unit * 0.14)
                            .background(Capsule().fill(accent))
                    }
                    .buttonStyle(.plain)
                }
            }

            label(strings.phoneAddress)
            Text(verbatim: localIP)
                .font(.system(size: unit * 0.5, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .font(.system(size: unit * 0.4, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: unit * 0.6, height: unit * 0.6)
                .background(Circle().fill(Color.white.opacity(0.1)))
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Oyun tarafi

    private var gamePanel: some View {
        VStack(alignment: .leading, spacing: unit * 0.12) {
            label(strings.gameSettings)
            row("UDP Telemetry", "On")
            row("UDP Broadcast Mode", "Off")
            row("UDP IP Address", localIP)
            row("UDP Port", "\(port)")
            row("UDP Send Rate", "60 Hz")
            row("UDP Format", "2026")
            row("Your Telemetry", "Public")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(unit * 0.3)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
        )
    }

    private func row(_ name: String, _ value: String) -> some View {
        HStack {
            Text(verbatim: name)
                .foregroundStyle(.white.opacity(0.6))
            Spacer(minLength: unit * 0.3)
            Text(verbatim: value)
                .foregroundStyle(accent)
        }
        .font(.system(size: unit * 0.28, weight: .heavy, design: .monospaced))
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: unit * 0.24, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white.opacity(0.4))
            .tracking(2)
    }
}
