import SwiftUI

/// Explains how to follow laps in a browser: which address to open, how to scan the QR and
/// what happens next. Opened from Settings.
struct WebGuideView: View {
    let strings: Strings
    let unit: CGFloat
    @Binding var sessionID: String
    @ObservedObject var pairing: SitePairing
    /// The phone's local analysis address, for opening it without the QR.
    var localAddress: String? = nil
    @ObservedObject var server: LocalAnalysisServer
    let onClose: () -> Void

    @State private var showsScanner = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: unit * 0.3) {
            HStack {
                Text(strings.webGuideTitle)
                    .font(Typeface.font(unit * 0.5, .black))
                    .foregroundStyle(.white)
                    .tracking(4)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(Typeface.font(unit * 0.34, .black))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(unit * 0.2)
                }
                .buttonStyle(PressScaleStyle())
            }

            // The title stays fixed; the content scrolls on small screens.
            ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: unit * 0.3) {
            Text(verbatim: strings.webGuideIntro)
                .font(Typeface.font(unit * 0.28, .medium))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            // The address: readable at a glance, with copy and share next to it.
            HStack(spacing: unit * 0.25) {
                Image(systemName: "safari")
                    .font(Typeface.font(unit * 0.5, .bold))
                    .foregroundStyle(Palette.accent)
                Text(verbatim: LapExport.siteHost)
                    .font(Typeface.font(unit * 0.52, .black))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Spacer(minLength: unit * 0.3)
                Button {
                    UIPasteboard.general.string = LapExport.siteURL
                    withAnimation(.spring(duration: 0.25)) { copied = true }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation(.spring(duration: 0.25)) { copied = false }
                    }
                } label: {
                    Label(copied ? strings.copied : strings.copyLink,
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(Typeface.font(unit * 0.24, .heavy))
                        .foregroundStyle(copied ? Palette.live : .white.opacity(0.75))
                        .padding(.horizontal, unit * 0.26)
                        .padding(.vertical, unit * 0.12)
                        .background(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                }
                .buttonStyle(PressScaleStyle())

                ShareLink(item: URL(string: LapExport.siteURL)!) {
                    Image(systemName: "square.and.arrow.up")
                        .font(Typeface.font(unit * 0.3, .heavy))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(unit * 0.16)
                        .background(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                }
                .buttonStyle(PressScaleStyle())
            }
            .padding(.horizontal, unit * 0.4)
            .padding(.vertical, unit * 0.22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
                .fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
                .stroke(Palette.accent.opacity(0.5), lineWidth: 1.5))

            HStack(alignment: .top, spacing: unit * 0.4) {
                step(1, strings.webGuideStep1)
                step(2, strings.webGuideStep2)
                step(3, strings.webGuideStep3)
            }

            // Pairing: the QR is scanned from here.
            HStack(spacing: unit * 0.3) {
                if !server.viewers.isEmpty {
                    // Independent of the QR: a browser is actually reading from the phone.
                    HStack(spacing: unit * 0.16) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(verbatim: strings.browserConnected(server.viewers.joined(separator: ", ")))
                    }
                    .font(Typeface.font(unit * 0.28, .heavy))
                    .foregroundStyle(Palette.live)
                    .transition(.opacity)
                } else if sessionID.isEmpty {
                    Button { showsScanner = true } label: {
                        Label(strings.scanQR, systemImage: "qrcode.viewfinder")
                            .font(Typeface.font(unit * 0.3, .black))
                            .foregroundStyle(Palette.onAccent)
                            .padding(.horizontal, unit * 0.5)
                            .padding(.vertical, unit * 0.18)
                            .background(Capsule().fill(Palette.accent))
                    }
                    .buttonStyle(PressScaleStyle())

                    Text(verbatim: strings.webGuideNotPaired)
                        .font(Typeface.font(unit * 0.26, .heavy))
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    HStack(spacing: unit * 0.16) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(verbatim: strings.connectedTo(sessionID))
                    }
                    .font(Typeface.font(unit * 0.28, .heavy))
                    .foregroundStyle(Palette.live)

                    Button { sessionID = "" } label: {
                        Text(strings.disconnect)
                            .font(Typeface.font(unit * 0.24, .heavy))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .buttonStyle(PressScaleStyle())
                }
                Spacer(minLength: 0)
                if let date = pairing.lastPairedDate, !sessionID.isEmpty {
                    Text(verbatim: strings.lastSent(date.formatted(date: .omitted, time: .standard)))
                        .font(Typeface.font(unit * 0.22, .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            if let localAddress {
                Text(verbatim: strings.localAnalysisHint(localAddress.replacingOccurrences(of: "http://", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))))
                    .font(Typeface.font(unit * 0.24, .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .textSelection(.enabled)
            }
            }
            .padding(.bottom, unit * 0.3)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .fullScreenCover(isPresented: $showsScanner) {
            ZStack(alignment: .topTrailing) {
                QRScannerView { scanned in
                    if let id = SitePairing.sessionID(from: scanned) {
                        sessionID = id
                        pairing.pair(sessionID: id)
                    }
                    showsScanner = false
                }
                .ignoresSafeArea()

                Button { showsScanner = false } label: {
                    Image(systemName: "xmark")
                        .font(Typeface.font(18, .black))
                        .foregroundStyle(.black)
                        .padding(14)
                        .background(Circle().fill(.white))
                }
                .buttonStyle(PressScaleStyle())
                .padding(24)
            }
        }
        .padding(.horizontal, unit * 0.7)
        .padding(.vertical, unit * 0.45)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StripedBackground())
    }

    private func step(_ number: Int, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: unit * 0.12) {
            Text(verbatim: "\(number)")
                .font(Typeface.font(unit * 0.3, .black))
                .foregroundStyle(Palette.onAccent)
                .frame(width: unit * 0.56, height: unit * 0.56)
                .background(Circle().fill(Palette.accent))
            Text(verbatim: text)
                .font(Typeface.font(unit * 0.26, .medium))
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(unit * 0.3)
        .background(RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
            .fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
            .stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}
