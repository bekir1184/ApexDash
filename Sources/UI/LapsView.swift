import SwiftUI

/// Tamamlanan turlarin listesi: sektor renkleriyle tablo, CSV paylasimi ve
/// ayni turlari sitede acan QR.
struct LapsView: View {
    let laps: [CompletedLap]
    let bestSectorMS: [Int]
    let strings: Strings
    let unit: CGFloat
    @Binding var sessionID: String
    @ObservedObject var uploader: SessionUploader
    let payload: () -> SessionUploader.Payload
    let onClose: () -> Void


    private var bestLapMS: Int { laps.map(\.timeMS).min() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: unit * 0.25) {
            header

            if laps.isEmpty {
                Text(verbatim: strings.noLaps)
                    .font(Typeface.digits(unit * 0.32, .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                HStack(alignment: .top, spacing: unit * 0.5) {
                    table
                    sidebar
                }
            }
        }
        .padding(.horizontal, unit * 0.6)
        .padding(.vertical, unit * 0.4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private var header: some View {
        HStack {
            Text(strings.lapsTitle)
                .font(Typeface.digits(unit * 0.44, .black))
                .foregroundStyle(.white)
                .tracking(4)
            Spacer()
            Button(action: onClose) {
                Text(strings.close)
                    .font(Typeface.digits(unit * 0.26, .black))
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, unit * 0.3)
                    .padding(.vertical, unit * 0.12)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
        }
    }

    private var table: some View {
        ScrollView {
            VStack(spacing: unit * 0.06) {
                row(lap: nil)
                ForEach(laps.reversed()) { lap in
                    row(lap: lap)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func row(lap: CompletedLap?) -> some View {
        let isHeader = lap == nil
        HStack(spacing: unit * 0.1) {
            cell(isHeader ? "LAP" : "\(lap!.number)", width: unit * 1.1, header: isHeader)
            cell(isHeader ? "TIME" : DashboardModel.lapTimeText(lap!.timeMS),
                 width: unit * 2.4, header: isHeader,
                 tint: !isHeader && lap!.timeMS == bestLapMS ? SectorColour.purple.tint : nil)
            ForEach(0..<3, id: \.self) { index in
                let value = isHeader ? 0 : [lap!.sector1MS, lap!.sector2MS, lap!.sector3MS][index]
                cell(isHeader ? "S\(index + 1)" : DashboardModel.sectorText(value),
                     width: unit * 1.8, header: isHeader,
                     tint: isHeader ? nil : colour(index: index, time: value).tint)
            }
        }
        .padding(.vertical, unit * 0.05)
        .background(
            isHeader ? Color.clear
                     : (lap!.timeMS == bestLapMS ? SectorColour.purple.tint.opacity(0.12) : Color.white.opacity(0.03))
        )
    }

    private func cell(_ text: String, width: CGFloat, header: Bool, tint: Color? = nil) -> some View {
        Text(verbatim: text)
            .font(Typeface.digits(header ? unit * 0.22 : unit * 0.3,
                                  header ? .heavy : .bold))
            .foregroundStyle(header ? .white.opacity(0.4) : (tint ?? .white))
            .frame(width: width, alignment: .trailing)
    }

    private func colour(index: Int, time: Int) -> SectorColour {
        guard time > 0 else { return .none }
        let best = bestSectorMS.indices.contains(index) ? bestSectorMS[index] : 0
        if best == 0 || time <= best { return .purple }
        return .yellow
    }

    private var sidebar: some View {
        VStack(spacing: unit * 0.24) {
            // Eslestirme ayarlardaki TELEMETRI SITESI sayfasinda; burada
            // yalnizca durum ve disari aktarma kalir.
            if sessionID.isEmpty {
                Text(verbatim: strings.pairInSettings)
                    .font(Typeface.digits(unit * 0.2, .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .frame(width: unit * 3.8)
            } else {
                VStack(spacing: unit * 0.06) {
                    Text(verbatim: strings.connectedTo(sessionID))
                        .font(Typeface.digits(unit * 0.24, .black))
                        .foregroundStyle(Palette.live)
                    if let date = uploader.lastUploadDate {
                        Text(verbatim: strings.lastSent(date.formatted(date: .omitted, time: .standard)))
                            .font(Typeface.digits(unit * 0.19, .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    if let error = uploader.lastError {
                        Text(verbatim: error)
                            .font(Typeface.digits(unit * 0.19, .semibold))
                            .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.35))
                            .lineLimit(2)
                    }
                }
                .frame(width: unit * 3.8)

                Button {
                    uploader.send(payload(), sessionID: sessionID)
                } label: {
                    Text(strings.sendNow)
                        .font(Typeface.digits(unit * 0.26, .black))
                        .foregroundStyle(Palette.onAccent)
                        .frame(width: unit * 3.6)
                        .padding(.vertical, unit * 0.14)
                        .background(Capsule().fill(Palette.accent))
                }
                .buttonStyle(.plain)
            }

            if let file = LapExport.csvFile(laps) {
                ShareLink(item: file) {
                    Text(strings.shareCSV)
                        .font(Typeface.digits(unit * 0.24, .black))
                        .foregroundStyle(.white)
                        .frame(width: unit * 3.6)
                        .padding(.vertical, unit * 0.12)
                        .background(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
