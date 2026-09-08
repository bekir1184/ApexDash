import SwiftUI

/// Tamamlanan turlarin listesi: sektor renkleriyle tablo, CSV paylasimi ve
/// ayni turlari sitede acan QR.
struct LapsView: View {
    let laps: [CompletedLap]
    let bestSectorMS: [Int]
    let strings: Strings
    let unit: CGFloat
    let onClose: () -> Void

    private var bestLapMS: Int { laps.map(\.timeMS).min() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: unit * 0.25) {
            header

            if laps.isEmpty {
                Text(verbatim: strings.noLaps)
                    .font(.system(size: unit * 0.32, weight: .semibold, design: .monospaced))
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
                .font(.system(size: unit * 0.44, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .tracking(4)
            Spacer()
            Button(action: onClose) {
                Text(strings.close)
                    .font(.system(size: unit * 0.26, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
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
            .font(.system(size: header ? unit * 0.22 : unit * 0.3,
                          weight: header ? .heavy : .bold, design: .monospaced))
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
        VStack(spacing: unit * 0.2) {
            if let url = LapExport.webURL(laps), let qr = LapExport.qrImage(for: url) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: unit * 3.4, height: unit * 3.4)
                    .padding(unit * 0.14)
                    .background(RoundedRectangle(cornerRadius: unit * 0.1).fill(.white))
                Text(verbatim: strings.scanForWeb)
                    .font(.system(size: unit * 0.2, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .frame(width: unit * 3.6)
            }

            if let file = LapExport.csvFile(laps) {
                ShareLink(item: file) {
                    Text(strings.shareCSV)
                        .font(.system(size: unit * 0.26, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(width: unit * 3.4)
                        .padding(.vertical, unit * 0.14)
                        .background(Capsule().fill(Color(red: 0.95, green: 0.85, blue: 0.15)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
