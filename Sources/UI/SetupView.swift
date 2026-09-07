import SwiftUI

/// Kurulum ekrani, direksiyonun kendisi gibi gorunur: ustte devir seridi,
/// ortada ayarlarin gectigi LCD, iki yanda dugmeler, altta dondurmeli
/// anahtarlar. Port bu dugmelerle ya da LCD'deki satira dokunup klavyeyle
/// degistirilir.
struct SetupView: View {
    @Binding var port: Int
    let strings: Strings
    let localIP: String
    let unit: CGFloat
    let onDone: () -> Void

    @State private var portText: String = ""
    @FocusState private var portFocused: Bool

    private let amber = Color(red: 0.97, green: 0.82, blue: 0.16)
    private let red = Color(red: 0.85, green: 0.11, blue: 0.12)
    private let cyan = Color(red: 0.35, green: 0.85, blue: 0.95)

    var body: some View {
        ZStack {
            CarbonBackground(pitch: max(6, unit * 0.22))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { portFocused = false }

            VStack(spacing: unit * 0.16) {
                ledStrip

                HStack(alignment: .center, spacing: unit * 0.28) {
                    leftCluster
                    lcd
                    rightCluster
                }

                dials
            }
            .padding(.horizontal, unit * 0.3)
            .padding(.vertical, unit * 0.2)
        }
        .onAppear { portText = "\(port)" }
    }

    // MARK: - Govde uzerindeki isikler

    private var ledStrip: some View {
        HStack(spacing: 0) {
            ForEach(0..<15, id: \.self) { index in
                let color: Color = index < 5
                    ? Color(red: 0.18, green: 0.92, blue: 0.32)
                    : (index < 10 ? Color(red: 1.0, green: 0.2, blue: 0.16)
                                  : Color(red: 0.5, green: 0.42, blue: 1.0))
                Circle()
                    .fill(color.opacity(0.22))
                    .frame(width: unit * 0.26, height: unit * 0.26)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Ekran

    private var lcd: some View {
        VStack(spacing: 0) {
            HStack {
                Text(strings.setupTitle)
                    .tracking(4)
                Spacer()
                Text(verbatim: "F1 26 · UDP")
            }
            .font(.system(size: unit * 0.3, weight: .black, design: .monospaced))
            .foregroundStyle(.black)
            .padding(.horizontal, unit * 0.24)
            .padding(.vertical, unit * 0.08)
            .frame(maxWidth: .infinity)
            .background(amber)

            VStack(spacing: unit * 0.06) {
                portRow
                row(strings.phoneAddress, localIP, tint: .white)
                Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1)
                    .padding(.vertical, unit * 0.04)
                row("UDP TELEMETRY", "ON")
                row("UDP BROADCAST", "OFF")
                row("UDP SEND RATE", "60 HZ")
                row("UDP FORMAT", "2026")
                row("YOUR TELEMETRY", "PUBLIC")
            }
            .padding(.horizontal, unit * 0.24)
            .padding(.vertical, unit * 0.12)

            Text(verbatim: strings.broadcastNote)
                .font(.system(size: unit * 0.19, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, unit * 0.24)
                .padding(.bottom, unit * 0.12)
        }
        .background(Color(red: 0.055, green: 0.06, blue: 0.05))
        .clipShape(RoundedRectangle(cornerRadius: unit * 0.12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.12, style: .continuous)
                .stroke(Color.black.opacity(0.9), lineWidth: unit * 0.1)
        )
    }

    /// LCD'de secili duran satir: dokununca klavye acilir.
    private var portRow: some View {
        HStack(spacing: unit * 0.16) {
            Text(strings.portLabel)
                .foregroundStyle(.black.opacity(0.75))
                .lineLimit(1)
            Spacer(minLength: unit * 0.2)
            TextField("20777", text: $portText)
                .keyboardType(.numberPad)
                .focused($portFocused)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.black)
                .frame(width: unit * 2.2)
                .onChange(of: portText) { _, new in
                    let digits = String(new.filter(\.isNumber).prefix(5))
                    if digits != new { portText = digits }
                    if let value = Int(digits), (1024...65535).contains(value) { port = value }
                }
            if portFocused {
                Button { portFocused = false } label: {
                    Text(verbatim: "OK")
                        .font(.system(size: unit * 0.22, weight: .black, design: .monospaced))
                        .foregroundStyle(amber)
                        .padding(.horizontal, unit * 0.18)
                        .padding(.vertical, unit * 0.06)
                        .background(Capsule().fill(.black))
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: unit * 0.34, weight: .black, design: .monospaced))
        .padding(.horizontal, unit * 0.16)
        .padding(.vertical, unit * 0.08)
        .background(RoundedRectangle(cornerRadius: unit * 0.08, style: .continuous).fill(amber))
    }

    private func row(_ name: String, _ value: String, tint: Color? = nil) -> some View {
        HStack(spacing: unit * 0.16) {
            Text(verbatim: name)
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
            Text(verbatim: value)
                .foregroundStyle(tint ?? cyan)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(.system(size: unit * 0.26, weight: .heavy, design: .monospaced))
    }

    // MARK: - Dugmeler

    private var leftCluster: some View {
        VStack(spacing: unit * 0.22) {
            WheelButton(title: "−", caption: "PORT", color: cyan, unit: unit) { adjustPort(-1) }
            WheelButton(title: "N", caption: "NEUTRAL", color: Color(white: 0.75), unit: unit) {
                portFocused = false
            }
        }
    }

    private var rightCluster: some View {
        VStack(spacing: unit * 0.22) {
            WheelButton(title: "+", caption: "PORT", color: cyan, unit: unit) { adjustPort(1) }
            WheelButton(title: "GO", caption: strings.startButton, color: red, unit: unit, action: onDone)
        }
    }

    private func adjustPort(_ delta: Int) {
        portFocused = false
        let value = min(max(port + delta, 1024), 65535)
        port = value
        portText = "\(value)"
    }

    // MARK: - Dondurmeli anahtarlar

    private var dials: some View {
        HStack(spacing: unit * 0.5) {
            RotaryDial(label: "STRAT", positions: 12, value: 3, color: amber, unit: unit)
            RotaryDial(label: "DIFF", positions: 12, value: 7, color: red, unit: unit)
            RotaryDial(label: "BBAL", positions: 12, value: 10, color: cyan, unit: unit)
        }
    }
}
