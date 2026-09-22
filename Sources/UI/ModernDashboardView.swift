import SwiftUI

/// A clean, high contrast layout in the style of a Bosch DDU.
struct ModernDashboardView: View {
    let dash: DashboardModel
    let unit: CGFloat
    let strings: Strings

    var body: some View {
        VStack(spacing: unit * 0.4) {
            RevLightsView(bits: dash.revLightsBits, flashing: dash.shiftFlash)
                .frame(height: unit * 0.8)

            HStack(alignment: .center, spacing: unit * 0.5) {
                leftColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
                gearBlock
                TyreTempsView(tyreSurface: dash.tyreSurfaceTemps,
                              tyreInner: dash.tyreInnerTemps,
                              brakes: dash.brakeTemps,
                              unit: unit,
                              innerLabel: strings.tyreInner)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxHeight: .infinity)

            PedalBarsView(throttle: dash.throttle, brake: dash.brake)
                .frame(height: unit * 0.45)
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: unit * 0.16) {
            label("SPEED")
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "\(dash.speedKPH)")
                    .font(.system(size: unit * 1.7, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("KM/H")
                    .font(.system(size: unit * 0.33, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            HStack(spacing: unit * 0.25) {
                badge(text: dash.boostLabel, active: dash.boostActive, ready: dash.boostAvailable,
                      color: Color(red: 0.99, green: 0.78, blue: 0.15))
                if !dash.usesDRS {
                    badge(text: dash.aeroLabel, active: dash.aeroEngaged, ready: dash.aeroReady,
                          color: Color(red: 0.24, green: 0.78, blue: 1.0))
                }
                if dash.pitLimiterOn {
                    badge(text: "PIT", active: true, ready: true,
                          color: Color(red: 1.0, green: 0.35, blue: 0.35))
                }
            }
            label("LAP \(dash.currentLapNum)")
            Text(verbatim: dash.currentLapTimeText)
                .font(.system(size: unit * 0.62, weight: .bold, design: .monospaced))
                .foregroundStyle(dash.currentLapInvalid ? Color.red.opacity(0.8) : .white.opacity(0.8))
        }
    }

    private var gearBlock: some View {
        VStack(spacing: unit * 0.1) {
            Text(verbatim: dash.gearLabel)
                .font(.system(size: unit * 4.0, weight: .black, design: .monospaced))
                .foregroundStyle(dash.shiftFlash ? Color(red: 0.36, green: 0.44, blue: 1.0) : .white)
                .shadow(color: dash.shiftFlash ? Color.blue.opacity(0.8) : .clear, radius: unit * 0.4)
                .animation(.easeOut(duration: 0.08), value: dash.shiftFlash)

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.08))
                .frame(width: unit * 3.8, height: unit * 0.16)
                .overlay(alignment: .leading) {
                    GeometryReader { g in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [.green, .yellow, .red],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * dash.rpmFraction)
                    }
                }
        }
    }

    private func badge(text: String, active: Bool, ready: Bool, color: Color) -> some View {
        let ink: Color = active ? .black : (ready ? color : Color.white.opacity(0.18))
        let fill: Color = active ? color : Color.white.opacity(0.05)
        let edge: Color = ready ? color.opacity(0.7) : Color.white.opacity(0.1)
        let shape = RoundedRectangle(cornerRadius: unit * 0.14, style: .continuous)
        return Text(text)
            .font(.system(size: unit * 0.32, weight: .black, design: .monospaced))
            .foregroundStyle(ink)
            .padding(.horizontal, unit * 0.28)
            .padding(.vertical, unit * 0.14)
            .background(shape.fill(fill))
            .overlay(shape.stroke(edge, lineWidth: 1.5))
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: unit * 0.22, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white.opacity(0.35))
            .tracking(2)
    }
}
