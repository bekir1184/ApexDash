import SwiftUI

/// A dot matrix layout imitating a real F1 wheel LCD. Overtake and active aero indicators
/// at the top, a rev ladder below, a giant gear in the middle with tyre temperatures at its
/// four corners, the battery (boost) column on the right and lap time at the bottom.
struct DotMatrixDashboardView: View {
    let dash: DashboardModel
    let unit: CGFloat

    private let panelStroke = Color.white.opacity(0.55)
    private let cyan = Color(red: 0.35, green: 0.85, blue: 0.95)
    private let green = Color(red: 0.24, green: 0.92, blue: 0.29)
    private let batteryYellow = Color(red: 0.98, green: 0.82, blue: 0.15)
    private let aeroMagenta = Color(red: 0.85, green: 0.35, blue: 0.95)

    var body: some View {
        VStack(spacing: unit * 0.16) {
            HStack(spacing: unit * 0.16) {
                batteryBanner
                straightModeBanner
            }
            revLadder
            HStack(alignment: .center, spacing: unit * 0.18) {
                leftStack
                gearWithTyres
                rightStack
            }
            .frame(maxHeight: .infinity)
            bottomRow
        }
        .padding(unit * 0.1)
        .dotMatrix(pitch: max(2, unit * 0.055))
    }

    // MARK: - Top indicators

    /// Battery: energy available for overtake. Flashes when full.
    private var batteryBanner: some View {
        let full = dash.ersFraction >= 0.99
        return TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let phase = Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 2 == 0
            banner(text: "BATTERY",
                   detail: "\(Int(dash.ersFraction * 100))%",
                   color: batteryYellow,
                   filled: full && phase,
                   dimmed: false,
                   fillFraction: dash.ersFraction)
        }
    }

    /// Active aero: the X (corner) / Z (straight) mode that replaces DRS in 2026. Flashes
    /// when available but not engaged.
    private var straightModeBanner: some View {
        let engaged = dash.aeroEngaged
        let waiting = dash.aeroReady && !engaged
        return TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let phase = Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 2 == 0
            banner(text: dash.usesDRS ? "DRS" : "STRAIGHT MODE",
                   detail: "",
                   color: aeroMagenta,
                   filled: engaged || (waiting && phase),
                   dimmed: !engaged && !waiting,
                   fillFraction: 0)
        }
    }

    /// With `fillFraction`, the badge background fills to that level (battery level).
    private func banner(text: String, detail: String, color: Color,
                        filled: Bool, dimmed: Bool, fillFraction: Double) -> some View {
        let foreground: Color = filled ? .black : (dimmed ? .white.opacity(0.3) : color)
        return HStack(spacing: unit * 0.16) {
            Text(text)
                .font(.system(size: unit * 0.46, weight: .black, design: .monospaced))
            if !detail.isEmpty {
                Text(verbatim: detail)
                    .font(.system(size: unit * 0.46, weight: .black, design: .monospaced))
                    .opacity(0.9)
            }
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .padding(.vertical, unit * 0.12)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                .fill(filled ? color : Color.white.opacity(0.05))
                .overlay(alignment: .leading) {
                    if !filled && fillFraction > 0 {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                                .fill(color.opacity(0.28))
                                .frame(width: geo.size.width * fillFraction)
                        }
                    }
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                .stroke(filled ? .clear : (dimmed ? Color.white.opacity(0.2) : color.opacity(0.7)),
                        lineWidth: 1.5)
        )
    }

    /// Horizontal rev ladder: green, yellow, red; fully lit at the shift point.
    private var revLadder: some View {
        GeometryReader { geo in
            let count = 24
            let spacing = geo.size.width * 0.004
            let width = (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            let lit = Int((dash.rpmFraction * Double(count)).rounded())
            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { index in
                    Rectangle()
                        .fill(index < lit || dash.shiftFlash ? revColor(index, of: count)
                                                             : Color.white.opacity(0.07))
                        .frame(width: width)
                }
            }
        }
        .frame(height: unit * 0.3)
    }

    private func revColor(_ index: Int, of total: Int) -> Color {
        if dash.shiftFlash { return Color(red: 0.55, green: 0.45, blue: 1.0) }
        let ratio = Double(index) / Double(total)
        switch ratio {
        case ..<0.55: return Color(red: 0.22, green: 0.85, blue: 0.3)
        case ..<0.82: return Color(red: 0.95, green: 0.8, blue: 0.15)
        default: return Color(red: 0.95, green: 0.22, blue: 0.18)
        }
    }

    // MARK: - Left column

    private var leftStack: some View {
        VStack(spacing: unit * 0.14) {
            panel(value: "\(dash.averageBrakeTemp)°", caption: "BRAKE",
                  tint: TempScale.brake(dash.averageBrakeTemp))
            panel(value: String(format: "%.1f", dash.fuelRemainingLaps), caption: "FUEL",
                  tint: dash.fuelRemainingLaps < 0 ? Color(red: 1, green: 0.35, blue: 0.3) : .white)
        }
        .frame(width: unit * 2.4)
    }

    private func panel(value: String, caption: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text(verbatim: value)
                .font(.system(size: unit * 0.58, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(caption)
                .font(.system(size: unit * 0.3, weight: .heavy, design: .monospaced))
                .foregroundStyle(cyan)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, unit * 0.08)
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                .stroke(panelStroke, lineWidth: 1.5)
        )
    }

    // MARK: - Gear and the tyres around it

    /// The four wheels at the gear's corners, laid out as on the car: FL / FR on top, RL /
    /// RR below.
    private var gearWithTyres: some View {
        HStack(spacing: unit * 0.25) {
            VStack(spacing: unit * 0.4) {
                tyreCell(index: 2, label: "FL")
                tyreCell(index: 0, label: "RL")
            }
            Text(verbatim: dash.gearLabel)
                .font(.system(size: unit * 3.0, weight: .black, design: .monospaced))
                .foregroundStyle(dash.shiftFlash ? Color(red: 0.55, green: 0.45, blue: 1.0) : .white)
                .animation(.easeOut(duration: 0.08), value: dash.shiftFlash)
                .frame(maxWidth: .infinity)
            VStack(spacing: unit * 0.4) {
                tyreCell(index: 3, label: "FR")
                tyreCell(index: 1, label: "RR")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tyreCell(index: Int, label: String) -> some View {
        let surface = dash.tyreSurfaceTemps.indices.contains(index) ? dash.tyreSurfaceTemps[index] : 0
        let brake = dash.brakeTemps.indices.contains(index) ? dash.brakeTemps[index] : 0
        return VStack(spacing: 0) {
            Text(label)
                .font(.system(size: unit * 0.26, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
            Text(verbatim: "\(surface)°")
                .font(.system(size: unit * 0.52, weight: .black, design: .monospaced))
                .foregroundStyle(TempScale.tyre(surface))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(verbatim: "\(brake)°")
                .font(.system(size: unit * 0.28, weight: .bold, design: .monospaced))
                .foregroundStyle(TempScale.brake(brake))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: unit * 1.5)
        .padding(.vertical, unit * 0.06)
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.09, style: .continuous)
                .stroke(TempScale.tyre(surface).opacity(0.5), lineWidth: 1.2)
        )
    }

    // MARK: - Right column: battery

    private var rightStack: some View {
        HStack(spacing: unit * 0.18) {
            batteryColumn
            VStack(alignment: .leading, spacing: unit * 0.04) {
                Text(verbatim: "\(Int(dash.ersFraction * 100))%")
                    .font(.system(size: unit * 0.68, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("BATTERY")
                    .font(.system(size: unit * 0.32, weight: .black, design: .monospaced))
                    .foregroundStyle(batteryYellow)
                Text(dash.ersModeText)
                    .font(.system(size: unit * 0.28, weight: .heavy, design: .monospaced))
                    .foregroundStyle(cyan)
                Spacer(minLength: 0)
                Text(verbatim: "P\(max(dash.carPosition, 1))")
                    .font(.system(size: unit * 0.6, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text(verbatim: "LAP \(dash.currentLapNum)")
                    .font(.system(size: unit * 0.32, weight: .heavy, design: .monospaced))
                    .foregroundStyle(cyan)
            }
        }
        .frame(width: unit * 2.9)
        .padding(unit * 0.1)
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                .stroke(panelStroke, lineWidth: 1.5)
        )
    }

    /// ERS store column: energy available for overtake.
    private var batteryColumn: some View {
        let segments = 14
        let lit = Int((dash.ersFraction * Double(segments)).rounded())
        return VStack(spacing: unit * 0.04) {
            ForEach(0..<segments, id: \.self) { index in
                let fromTop = segments - index
                Rectangle()
                    .fill(fromTop <= lit ? batteryColor(fromTop, of: segments)
                                         : Color.white.opacity(0.07))
                    .frame(height: unit * 0.13)
            }
        }
        .frame(width: unit * 0.55)
    }

    private func batteryColor(_ level: Int, of total: Int) -> Color {
        let ratio = Double(level) / Double(total)
        switch ratio {
        case ..<0.25: return Color(red: 0.95, green: 0.22, blue: 0.18)
        default: return batteryYellow
        }
    }

    /// Against the best lap: green when ahead, red when behind.
    private var bestDeltaColor: Color {
        guard let delta = dash.deltaToBestMS else { return .white.opacity(0.75) }
        if delta < -20 { return green }
        if delta > 20 { return Color(red: 1.0, green: 0.28, blue: 0.24) }
        return .white.opacity(0.85)
    }

    /// Green when closing, red when dropping back, neutral when steady.
    private var deltaColor: Color {
        switch dash.deltaTrend {
        case ..<0: return green
        case 1...: return Color(red: 1.0, green: 0.28, blue: 0.24)
        default: return .white.opacity(0.75)
        }
    }

    // MARK: - Bottom row

    private var bottomRow: some View {
        HStack(spacing: unit * 0.16) {
            HStack(alignment: .firstTextBaseline, spacing: unit * 0.25) {
                Text(verbatim: dash.currentLapTimeText)
                    .font(.system(size: unit * 0.72, weight: .black, design: .monospaced))
                    .foregroundStyle(dash.currentLapInvalid ? Color(red: 1, green: 0.4, blue: 0.4) : .white)
                if dash.deltaToBestMS != nil {
                    Text(verbatim: dash.deltaToBestText)
                        .font(.system(size: unit * 0.46, weight: .black, design: .monospaced))
                        .foregroundStyle(bestDeltaColor)
                } else if dash.deltaToCarInFrontMS > 0 {
                    Text(verbatim: dash.deltaToFrontText)
                        .font(.system(size: unit * 0.44, weight: .black, design: .monospaced))
                        .foregroundStyle(deltaColor)
                }
            }
                .frame(maxWidth: .infinity)
                .padding(.vertical, unit * 0.08)
                .overlay(
                    RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                        .stroke(panelStroke, lineWidth: 1.5)
                )
            SectorStrip(dash: dash, unit: unit)
                .frame(width: unit * 3.6)

            Text(verbatim: "\(dash.speedKPH) KM/H")
                .font(.system(size: unit * 0.62, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: unit * 3.4)
                .padding(.vertical, unit * 0.08)
                .overlay(
                    RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                        .stroke(panelStroke, lineWidth: 1.5)
                )
        }
    }
}
