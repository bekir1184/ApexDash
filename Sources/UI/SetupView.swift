import SwiftUI

/// The connection screen, opened on first launch and from the connection badge. It picks
/// the game. For F1 the port set here is both where the app listens and the value to enter
/// in the game; for ACC the phone connects to the PC address entered here.
struct SetupView: View {
    @Binding var port: Int
    /// The year that must match the UDP Format in the game (2025 / 2026).
    @Binding var format: Int
    /// `GameChoice` raw value.
    @Binding var gameID: String
    @Binding var accAddress: String
    @Binding var accPassword: String
    /// The format the game actually sends when it differs, for example "F1 25".
    var mismatch: String? = nil
    let strings: Strings
    let localIP: String
    let unit: CGFloat
    let onDone: () -> Void

    @State private var portText: String = ""
    @FocusState private var portFocused: Bool
    @FocusState private var accFocused: Bool

    private var game: GameChoice { GameChoice.resolve(gameID) }

    private let accent = Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: unit * 0.26) {
            HStack {
                Text(strings.setupTitle)
                    .font(Typeface.digits(unit * 0.5, .black))
                    .foregroundStyle(.white)
                    .tracking(4)
                Spacer()
                gamePicker
                Button(action: onDone) {
                    Image(systemName: "xmark")
                        .font(Typeface.font(unit * 0.34, .black))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(unit * 0.2)
                }
                .buttonStyle(PressScaleStyle())
            }

            Text(verbatim: game == .acc ? strings.accSetupIntro : strings.setupIntro)
                .font(Typeface.digits(unit * 0.3, .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: unit * 0.5) {
                if game == .acc {
                    accPhonePanel
                    accGamePanel
                } else {
                    phonePanel
                    gamePanel
                }
            }

            Text(verbatim: game == .acc ? strings.accNote : strings.broadcastNote)
                .font(Typeface.digits(unit * 0.24, .semibold))
                .foregroundStyle(.white.opacity(0.35))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, unit * 0.7)
        .padding(.vertical, unit * 0.45)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StripedBackground())
        .contentShape(Rectangle())
        .onTapGesture { portFocused = false; accFocused = false }
        .onAppear { portText = "\(port)" }
    }

    // MARK: - Game picker

    private var gamePicker: some View {
        HStack(spacing: 0) {
            ForEach(GameChoice.allCases) { choice in
                Button {
                    portFocused = false
                    accFocused = false
                    withAnimation(.spring(duration: 0.3)) { gameID = choice.rawValue }
                } label: {
                    Text(verbatim: choice.title)
                        .foregroundStyle(game == choice ? Palette.onAccent : .white.opacity(0.55))
                        .padding(.horizontal, unit * 0.24)
                        .padding(.vertical, unit * 0.08)
                        .background {
                            if game == choice { Capsule().fill(accent) }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(game == choice ? .isSelected : [])
            }
        }
        .font(Typeface.digits(unit * 0.28, .heavy))
        .background(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        .accessibilityLabel(strings.gameLabel)
    }

    // MARK: - ACC

    /// Where the phone finds the game: the PC's address and the password.
    private var accPhonePanel: some View {
        VStack(alignment: .leading, spacing: unit * 0.2) {
            label(strings.pcAddress)
            accField("192.168.1.20", text: $accAddress, keyboard: .numbersAndPunctuation)
            label(strings.accPassword)
            accField("asd", text: $accPassword, keyboard: .asciiCapable)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accField(_ prompt: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: unit * 0.18) {
            TextField(prompt, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($accFocused)
                .submitLabel(.done)
                .onSubmit { accFocused = false }
                .textFieldStyle(.plain)
                .font(Typeface.digits(unit * 0.42, .black))
                .foregroundStyle(.white)
                .padding(.horizontal, unit * 0.25)
                .padding(.vertical, unit * 0.1)
                .background(
                    RoundedRectangle(cornerRadius: unit * 0.14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        }
    }

    /// The broadcasting.json values on the PC.
    private var accGamePanel: some View {
        VStack(alignment: .leading, spacing: unit * 0.12) {
            label(strings.accFile)
            row("updListenerPort", accPort)
            row("connectionPassword", accPassword.isEmpty ? "\"\"" : accPassword)
            row("commandPassword", "\"\"")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(unit * 0.3)
        .overlay(alignment: .bottomLeading) {
            if let mismatch {
                Label(strings.accRejected(mismatch), systemImage: "exclamationmark.triangle.fill")
                    .font(Typeface.digits(unit * 0.22, .heavy))
                    .foregroundStyle(accent)
                    .offset(y: unit * 0.45)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: unit * 0.16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
        )
    }

    /// The port in "address:port", else the default.
    private var accPort: String {
        let parts = accAddress.split(separator: ":")
        return parts.count == 2 ? String(parts[1]) : "\(ACCGame.defaultPort)"
    }

    // MARK: - Phone side

    private var phonePanel: some View {
        VStack(alignment: .leading, spacing: unit * 0.25) {
            label(strings.portLabel)
            HStack(spacing: unit * 0.18) {
                TextField("20777", text: $portText)
                    .keyboardType(.numberPad)
                    .focused($portFocused)
                    .textFieldStyle(.plain)
                .font(Typeface.digits(unit * 0.6, .black))
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
                            .font(Typeface.digits(unit * 0.26, .black))
                            .foregroundStyle(Palette.onAccent)
                            .padding(.horizontal, unit * 0.24)
                            .padding(.vertical, unit * 0.14)
                            .background(Capsule().fill(accent))
                    }
                    .buttonStyle(.plain)
                }
            }

            label(strings.phoneAddress)
            Text(verbatim: localIP)
                .font(Typeface.digits(unit * 0.5, .black))
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
                .font(Typeface.digits(unit * 0.4, .black))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: unit * 0.6, height: unit * 0.6)
                .background(Circle().fill(Color.white.opacity(0.1)))
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Game side

    private var gamePanel: some View {
        VStack(alignment: .leading, spacing: unit * 0.12) {
            label(strings.gameSettings)
            row("UDP Telemetry", "On")
            row("UDP Broadcast Mode", "Off")
            row("UDP IP Address", localIP)
            row("UDP Port", "\(port)")
            row("UDP Send Rate", "60 Hz")
            formatRow
            row("Your Telemetry", "Public")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(unit * 0.3)
        .overlay(alignment: .bottomLeading) {
            if let mismatch {
                Label(strings.formatMismatch(mismatch), systemImage: "exclamationmark.triangle.fill")
                    .font(Typeface.digits(unit * 0.22, .heavy))
                    .foregroundStyle(accent)
                    .offset(y: unit * 0.45)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: unit * 0.16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
        )
    }

    /// UDP Format choice in the game: switches between the two years.
    private var formatRow: some View {
        HStack {
            Text(verbatim: "UDP Format")
                .foregroundStyle(.white.opacity(0.6))
            Spacer(minLength: unit * 0.3)
            HStack(spacing: 0) {
                ForEach([2025, 2026], id: \.self) { year in
                    Button {
                        withAnimation(.spring(duration: 0.3)) { format = year }
                    } label: {
                        Text(verbatim: "\(year)")
                            .foregroundStyle(format == year ? Palette.onAccent : .white.opacity(0.5))
                            .padding(.horizontal, unit * 0.18)
                            .padding(.vertical, unit * 0.03)
                            .background {
                                if format == year { Capsule().fill(accent) }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
        .font(Typeface.digits(unit * 0.28, .heavy))
    }

    private func row(_ name: String, _ value: String) -> some View {
        HStack {
            Text(verbatim: name)
                .foregroundStyle(.white.opacity(0.6))
            Spacer(minLength: unit * 0.3)
            Text(verbatim: value)
                .foregroundStyle(accent)
        }
        .font(Typeface.digits(unit * 0.28, .heavy))
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Typeface.digits(unit * 0.24, .heavy))
            .foregroundStyle(.white.opacity(0.4))
            .tracking(2)
    }
}
