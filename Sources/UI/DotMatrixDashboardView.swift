import SwiftUI

/// Gercek F1 direksiyon LCD'sini taklit eden nokta-matris duzen:
/// ustte durum bandi, solda delta ve sicakliklar, ortada dev vites ve tur
/// suresi, sagda devir seridi ile tur bilgisi.
struct DotMatrixDashboardView: View {
    let dash: DashboardModel
    let unit: CGFloat

    private let panelStroke = Color.white.opacity(0.55)

    var body: some View {
        VStack(spacing: unit * 0.2) {
            banner
            HStack(alignment: .top, spacing: unit * 0.3) {
                leftStack
                centerStack
                rightStack
            }
            .frame(maxHeight: .infinity)
            cornerStrip
        }
        .padding(unit * 0.1)
        .background(Color.black)
        .dotMatrix(pitch: max(2, unit * 0.055))
    }

    // MARK: - Ust bant

    private var banner: some View {
        let state = bannerState
        return Text(state.text)
            .font(.system(size: unit * 0.62, weight: .black, design: .monospaced))
            .tracking(unit * 0.12)
            .foregroundStyle(state.filled ? .black : state.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, unit * 0.16)
            .background(
                RoundedRectangle(cornerRadius: unit * 0.12, style: .continuous)
                    .fill(state.filled
                          ? LinearGradient(colors: [state.color, state.color.opacity(0.75)],
                                           startPoint: .leading, endPoint: .trailing)
                          : LinearGradient(colors: [Color.white.opacity(0.05)],
                                           startPoint: .leading, endPoint: .trailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: unit * 0.12, style: .continuous)
                    .stroke(state.color.opacity(state.filled ? 0 : 0.6), lineWidth: 1.5)
            )
    }

    private var bannerState: (text: String, color: Color, filled: Bool) {
        if dash.overtakeActive {
            return ("OVERTAKE ACTIVE", Color(red: 0.24, green: 0.92, blue: 0.29), true)
        }
        if dash.aeroStraightMode {
            return ("AERO Z · STRAIGHT", Color(red: 0.24, green: 0.78, blue: 1.0), true)
        }
        if dash.overtakeAvailable {
            return ("OVERTAKE READY", Color(red: 0.24, green: 0.92, blue: 0.29), false)
        }
        return ("AERO X · CORNER", Color.white.opacity(0.5), false)
    }

    // MARK: - Sol sutun

    private var leftStack: some View {
        VStack(spacing: unit * 0.18) {
            panel(value: dash.deltaToFrontText, caption: "DELTA 1", tint: .white)
            panel(value: "\(dash.averageTyreTemp)°", caption: "TYRE",
                  tint: TempScale.tyre(dash.averageTyreTemp))
            panel(value: "\(dash.averageBrakeTemp)°", caption: "BRAKE",
                  tint: TempScale.brake(dash.averageBrakeTemp))
            if dash.pitLimiterOn {
                Text("LIMITER")
                    .font(.system(size: unit * 0.34, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, unit * 0.12)
                    .background(Color(red: 0.95, green: 0.2, blue: 0.2))
            }
        }
        .frame(width: unit * 2.5)
    }

    private func panel(value: String, caption: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text(verbatim: value)
                .font(.system(size: unit * 0.62, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(caption)
                .font(.system(size: unit * 0.32, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 0.95))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, unit * 0.1)
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                .stroke(panelStroke, lineWidth: 1.5)
        )
    }

    // MARK: - Orta

    private var centerStack: some View {
        VStack(spacing: unit * 0.15) {
            Text(verbatim: dash.gearLabel)
                .font(.system(size: unit * 3.3, weight: .black, design: .monospaced))
                .foregroundStyle(dash.shiftFlash ? Color(red: 0.4, green: 0.75, blue: 1.0) : .white)
                .animation(.easeOut(duration: 0.08), value: dash.shiftFlash)
                .frame(maxHeight: .infinity)

            Text(verbatim: dash.currentLapTimeText)
                .font(.system(size: unit * 0.78, weight: .heavy, design: .monospaced))
                .foregroundStyle(dash.currentLapInvalid ? Color(red: 1, green: 0.4, blue: 0.4) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, unit * 0.1)
                .overlay(
                    RoundedRectangle(cornerRadius: unit * 0.14, style: .continuous)
                        .stroke(panelStroke, lineWidth: 1.5)
                )

            Text(verbatim: "\(dash.speedKPH) KM/H")
                .font(.system(size: unit * 0.38, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sag sutun

    private var rightStack: some View {
        HStack(spacing: unit * 0.2) {
            revColumn
            VStack(alignment: .leading, spacing: unit * 0.1) {
                Text(verbatim: "\(Int(dash.rpmFraction * 100))%")
                    .font(.system(size: unit * 0.72, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("RPM")
                    .font(.system(size: unit * 0.38, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer(minLength: 0)
                Text(verbatim: "P\(max(dash.carPosition, 1))")
                    .font(.system(size: unit * 0.62, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text(verbatim: "LAP \(dash.currentLapNum)")
                    .font(.system(size: unit * 0.34, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 0.95))
            }
        }
        .frame(width: unit * 2.9)
        .padding(unit * 0.12)
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                .stroke(panelStroke, lineWidth: 1.5)
        )
    }

    private var revColumn: some View {
        let segments = 14
        let lit = Int((dash.rpmFraction * Double(segments)).rounded())
        return VStack(spacing: unit * 0.04) {
            ForEach(0..<segments, id: \.self) { index in
                let fromTop = segments - index
                Rectangle()
                    .fill(fromTop <= lit ? segmentColor(index: index, of: segments)
                                         : Color.white.opacity(0.07))
                    .frame(height: unit * 0.14)
            }
        }
        .frame(width: unit * 0.6)
    }

    private func segmentColor(index: Int, of total: Int) -> Color {
        let ratio = Double(total - index) / Double(total)
        switch ratio {
        case ..<0.55: return Color(red: 0.22, green: 0.85, blue: 0.3)
        case ..<0.82: return Color(red: 0.95, green: 0.8, blue: 0.15)
        default: return Color(red: 0.95, green: 0.22, blue: 0.18)
        }
    }

    // MARK: - Alt serit

    private var cornerStrip: some View {
        HStack(spacing: unit * 0.15) {
            ForEach(Array(["FL", "FR", "RL", "RR"].enumerated()), id: \.offset) { position, label in
                let index = [2, 3, 0, 1][position]
                let tyre = dash.tyreSurfaceTemps.indices.contains(index) ? dash.tyreSurfaceTemps[index] : 0
                let brake = dash.brakeTemps.indices.contains(index) ? dash.brakeTemps[index] : 0
                HStack(spacing: unit * 0.08) {
                    Text(label)
                        .font(.system(size: unit * 0.3, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(verbatim: "\(tyre)°")
                        .font(.system(size: unit * 0.38, weight: .black, design: .monospaced))
                        .foregroundStyle(TempScale.tyre(tyre))
                    Text(verbatim: "\(brake)°")
                        .font(.system(size: unit * 0.3, weight: .bold, design: .monospaced))
                        .foregroundStyle(TempScale.brake(brake))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, unit * 0.06)
                .overlay(
                    RoundedRectangle(cornerRadius: unit * 0.08, style: .continuous)
                        .stroke(panelStroke.opacity(0.6), lineWidth: 1)
                )
            }
        }
    }
}
