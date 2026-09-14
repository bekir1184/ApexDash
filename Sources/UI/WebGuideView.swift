import SwiftUI

/// Turlarin laptopta nasil izlenecegini anlatan sayfa: hangi adres acilir,
/// QR nasil okutulur, sonra ne olur. Ayarlardan acilir.
struct WebGuideView: View {
    let strings: Strings
    let unit: CGFloat
    @Binding var sessionID: String
    @ObservedObject var uploader: SessionUploader
    let payload: () -> SessionUploader.Payload
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

            Text(verbatim: strings.webGuideIntro)
                .font(Typeface.font(unit * 0.28, .medium))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            // Adres: bir bakista okunur, yanindan kopyalanir ya da paylasilir.
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

            // Eslestirme: QR buradan okutulur.
            HStack(spacing: unit * 0.3) {
                if sessionID.isEmpty {
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

                    Button { uploader.send(payload(), sessionID: sessionID) } label: {
                        Text(strings.sendNow)
                            .font(Typeface.font(unit * 0.26, .black))
                            .foregroundStyle(Palette.onAccent)
                            .padding(.horizontal, unit * 0.4)
                            .padding(.vertical, unit * 0.14)
                            .background(Capsule().fill(Palette.accent))
                    }
                    .buttonStyle(PressScaleStyle())

                    Button { sessionID = "" } label: {
                        Text(strings.disconnect)
                            .font(Typeface.font(unit * 0.24, .heavy))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .buttonStyle(PressScaleStyle())
                }
                Spacer(minLength: 0)
                if let date = uploader.lastUploadDate, !sessionID.isEmpty {
                    Text(verbatim: strings.lastSent(date.formatted(date: .omitted, time: .standard)))
                        .font(Typeface.font(unit * 0.22, .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer(minLength: 0)
        }
        .fullScreenCover(isPresented: $showsScanner) {
            ZStack(alignment: .topTrailing) {
                QRScannerView { scanned in
                    if let id = SessionUploader.sessionID(from: scanned) {
                        sessionID = id
                        uploader.send(payload(), sessionID: id)
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
