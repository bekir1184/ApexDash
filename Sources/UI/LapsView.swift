import SwiftUI

/// Completed laps: a table with sector colours, CSV export and whether a browser is
/// following along.
struct LapsView: View {
    let laps: [CompletedLap]
    let bestSectorMS: [Int]
    let strings: Strings
    let unit: CGFloat
    @ObservedObject var server: LocalAnalysisServer
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
                Image(systemName: "xmark")
                    .font(Typeface.font(unit * 0.34, .black))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(unit * 0.2)
            }
            .buttonStyle(PressScaleStyle())
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
            // Pairing lives on the telemetry site screen in Settings; this
            // sidebar only shows whether a browser is reading and offers export.
            if server.viewers.isEmpty {
                Text(verbatim: strings.pairInSettings)
                    .font(Typeface.digits(unit * 0.2, .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .frame(width: unit * 3.8)
            } else {
                Text(verbatim: strings.browserConnected(server.viewers.joined(separator: ", ")))
                    .font(Typeface.digits(unit * 0.22, .black))
                    .foregroundStyle(Palette.live)
                    .multilineTextAlignment(.center)
                    .frame(width: unit * 3.8)
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
