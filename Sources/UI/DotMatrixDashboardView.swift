import SwiftUI

/// Gercek F1 direksiyon LCD'sini taklit eden nokta-matris duzen.
/// Ustte overtake ve aktif aero ayri gostergeler, altinda devir merdiveni,
/// ortada dev vites ve dort kosesinde lastik sicakliklari, sagda batarya
/// (boost) kolonu, altta tur suresi.
struct DotMatrixDashboardView: View {
    let dash: DashboardModel
    let unit: CGFloat

    private let panelStroke = Color.white.opacity(0.55)
    private let cyan = Color(red: 0.35, green: 0.85, blue: 0.95)
    private let green = Color(red: 0.24, green: 0.92, blue: 0.29)
    private let aeroBlue = Color(red: 0.24, green: 0.78, blue: 1.0)

    var body: some View {
        VStack(spacing: unit * 0.16) {
            HStack(spacing: unit * 0.16) {
                overtakeBanner
                aeroBanner
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
        .background(Color.black)
        .dotMatrix(pitch: max(2, unit * 0.055))
    }

    // MARK: - Ust gostergeler

    /// Manual override (overtake). 2026'da fazladan elektrik gucu bataryadan
    /// cekildigi icin doluluk yuzdesi de burada gosteriliyor.
    private var overtakeBanner: some View {
        banner(text: dash.overtakeActive ? "OVERTAKE ACTIVE"
                                         : (dash.overtakeAvailable ? "OVERTAKE READY" : "OVERTAKE"),
               detail: "\(Int(dash.ersFraction * 100))%",
               color: green,
               filled: dash.overtakeActive,
               dimmed: !dash.overtakeAvailable && !dash.overtakeActive)
    }

    /// Aktif aero: 2026 kurallarinda DRS'in yerini alan X (viraj) / Z (duz) modu.
    private var aeroBanner: some View {
        banner(text: dash.aeroStraightMode ? "STRAIGHT MODE" : "CORNER MODE",
               detail: dash.aeroStraightMode ? "Z" : "X",
               color: aeroBlue,
               filled: dash.aeroStraightMode,
               dimmed: !dash.aeroAvailable && !dash.aeroStraightMode)
    }

    private func banner(text: String, detail: String, color: Color,
                        filled: Bool, dimmed: Bool) -> some View {
        let foreground: Color = filled ? .black : (dimmed ? .white.opacity(0.3) : color)
        return HStack(spacing: unit * 0.16) {
            Text(text)
                .font(.system(size: unit * 0.46, weight: .black, design: .monospaced))
            Text(verbatim: detail)
                .font(.system(size: unit * 0.46, weight: .black, design: .monospaced))
                .opacity(0.9)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .padding(.vertical, unit * 0.12)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                .fill(filled ? color : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                .stroke(filled ? .clear : (dimmed ? Color.white.opacity(0.2) : color.opacity(0.7)),
                        lineWidth: 1.5)
        )
    }

    /// Yatay devir merdiveni: yesil, sari, kirmizi; shift noktasinda tamami yanar.
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

    // MARK: - Sol sutun

    private var leftStack: some View {
        VStack(spacing: unit * 0.14) {
            panel(value: dash.deltaToFrontText, caption: "DELTA 1", tint: .white)
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

    // MARK: - Vites ve cevresindeki lastikler

    /// Dort tekerlek, gercek arac yerlesimiyle vitesin kosesinde:
    /// ust satir FL / FR, alt satir RL / RR.
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

    // MARK: - Sag sutun: batarya

    private var rightStack: some View {
        HStack(spacing: unit * 0.18) {
            batteryColumn
            VStack(alignment: .leading, spacing: unit * 0.04) {
                Text(verbatim: "\(Int(dash.ersFraction * 100))%")
                    .font(.system(size: unit * 0.68, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("BOOST")
                    .font(.system(size: unit * 0.34, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
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

    /// ERS deposunun doluluk kolonu - overtake icin kullanilabilir enerji.
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
        case ..<0.5: return Color(red: 0.95, green: 0.8, blue: 0.15)
        default: return Color(red: 0.22, green: 0.85, blue: 0.3)
        }
    }

    // MARK: - Alt satir

    private var bottomRow: some View {
        HStack(spacing: unit * 0.16) {
            Text(verbatim: dash.currentLapTimeText)
                .font(.system(size: unit * 0.72, weight: .black, design: .monospaced))
                .foregroundStyle(dash.currentLapInvalid ? Color(red: 1, green: 0.4, blue: 0.4) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, unit * 0.08)
                .overlay(
                    RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                        .stroke(panelStroke, lineWidth: 1.5)
                )
            Text(verbatim: "\(dash.speedKPH) KM/H")
                .font(.system(size: unit * 0.62, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: unit * 4)
                .padding(.vertical, unit * 0.08)
                .overlay(
                    RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                        .stroke(panelStroke, lineWidth: 1.5)
                )
        }
    }
}
