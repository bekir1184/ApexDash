import SwiftUI

extension SectorColour {
    var tint: Color {
        switch self {
        case .purple: return Color(red: 0.72, green: 0.36, blue: 1.0)
        case .green: return Color(red: 0.24, green: 0.92, blue: 0.35)
        case .yellow: return Color(red: 0.97, green: 0.85, blue: 0.2)
        case .none: return Color.white.opacity(0.35)
        }
    }
}

/// S1 / S2 / S3 boxes. A sector without a time yet shows dashes.
struct SectorStrip: View {
    let dash: DashboardModel
    let unit: CGFloat
    var compact = false

    var body: some View {
        HStack(spacing: unit * 0.1) {
            cell(index: 0, time: dash.sector1MS)
            cell(index: 1, time: dash.sector2MS)
            cell(index: 2, time: sector3)
        }
    }

    /// The third sector is only known when the lap ends; until then it shows the last
    /// lap's.
    private var sector3: Int {
        dash.lastLap?.sector3MS ?? 0
    }

    private func cell(index: Int, time: Int) -> some View {
        let colour = colour(index: index, time: time)
        return VStack(spacing: 0) {
            if !compact {
                Text(verbatim: "S\(index + 1)")
                    .font(.system(size: unit * 0.2, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text(verbatim: DashboardModel.sectorText(time))
                .font(.system(size: unit * 0.3, weight: .black, design: .monospaced))
                .foregroundStyle(colour.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, unit * 0.05)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.07, style: .continuous)
                .fill(colour.tint.opacity(0.14))
        )
    }

    private func colour(index: Int, time: Int) -> SectorColour {
        guard time > 0 else { return .none }
        let best = dash.bestSectorMS.indices.contains(index) ? dash.bestSectorMS[index] : 0
        if best == 0 || time < best { return .purple }
        if time == best { return .green }
        return .yellow
    }
}

/// The sector time shown large for a few seconds right after a sector is completed.
struct SectorFlashView: View {
    let flash: SectorFlash
    let unit: CGFloat

    var body: some View {
        VStack(spacing: unit * 0.04) {
            Text(verbatim: "SECTOR \(flash.index + 1)")
                .font(.system(size: unit * 0.28, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(3)
            Text(verbatim: DashboardModel.sectorText(flash.timeMS))
                .font(.system(size: unit * 0.8, weight: .black, design: .monospaced))
                .foregroundStyle(flash.colour.tint)
        }
        .padding(.horizontal, unit * 0.45)
        .padding(.vertical, unit * 0.14)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.18, style: .continuous)
                .fill(.black.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.18, style: .continuous)
                .stroke(flash.colour.tint.opacity(0.8), lineWidth: 2)
        )
        .shadow(color: flash.colour.tint.opacity(0.5), radius: unit * 0.3)
    }
}
