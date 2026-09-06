import SwiftUI

/// Eldeki telemetriden cikarilabilecek en yogun ama okunur duzen:
/// ustte devir seridi, solda dort kose lastik (sicaklik + asinma), ortada
/// devir yayinin icinde vites ve hiz, sagda batarya ve durum rozetleri.
struct ProDashboardView: View {
    let dash: DashboardModel
    let unit: CGFloat

    private let cyan = Color(red: 0.35, green: 0.85, blue: 0.95)
    private let amber = Color(red: 1.0, green: 0.72, blue: 0.11)
    private let green = Color(red: 0.22, green: 0.92, blue: 0.38)

    var body: some View {
        VStack(spacing: unit * 0.22) {
            RevLightsView(bits: dash.revLightsBits, flashing: dash.shiftFlash)
                .frame(height: unit * 0.5)

            HStack(alignment: .center, spacing: unit * 0.3) {
                tyreBlock
                centerBlock
                rightBlock
            }
            .frame(maxHeight: .infinity)

            PedalBarsView(throttle: dash.throttle, brake: dash.brake)
                .frame(height: unit * 0.34)
        }
    }

    // MARK: - Lastikler

    private var tyreBlock: some View {
        VStack(spacing: unit * 0.14) {
            HStack(spacing: unit * 0.14) {
                tyreCorner(index: 2, label: "FL")
                tyreCorner(index: 3, label: "FR")
            }
            HStack(spacing: unit * 0.14) {
                tyreCorner(index: 0, label: "RL")
                tyreCorner(index: 1, label: "RR")
            }
        }
        .frame(width: unit * 4.3)
        .frame(maxHeight: .infinity)
    }

    private func tyreCorner(index: Int, label: String) -> some View {
        let surface = dash.tyreSurfaceTemps.indices.contains(index) ? dash.tyreSurfaceTemps[index] : 0
        let brake = dash.brakeTemps.indices.contains(index) ? dash.brakeTemps[index] : 0
        let wear = dash.tyreWear.indices.contains(index) ? dash.tyreWear[index] : 0
        return VStack(spacing: unit * 0.05) {
            HStack(spacing: unit * 0.1) {
                Text(label)
                    .font(.system(size: unit * 0.24, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer(minLength: 0)
                Text(verbatim: "\(brake)°")
                    .font(.system(size: unit * 0.24, weight: .bold, design: .monospaced))
                    .foregroundStyle(TempScale.brake(brake))
            }
            Text(verbatim: "\(surface)°")
                .font(.system(size: unit * 0.62, weight: .black, design: .monospaced))
                .foregroundStyle(TempScale.tyre(surface))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            wearBar(wear)
        }
        .padding(.horizontal, unit * 0.14)
        .padding(.vertical, unit * 0.1)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.14, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.14, style: .continuous)
                .stroke(TempScale.tyre(surface).opacity(0.45), lineWidth: 1.2)
        )
    }

    /// Lastik asinmasi: doldukça sariya, sonra kirmiziya doner.
    private func wearBar(_ wear: Float) -> some View {
        let fraction = min(max(Double(wear) / 100, 0), 1)
        let color: Color = wear < 25 ? green : (wear < 50 ? amber : Color(red: 1, green: 0.28, blue: 0.24))
        return HStack(spacing: unit * 0.08) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(color).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: unit * 0.11)
            Text(verbatim: "\(Int(wear))%")
                .font(.system(size: unit * 0.22, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    // MARK: - Orta blok

    private var centerBlock: some View {
        VStack(spacing: unit * 0.1) {
            HStack(spacing: unit * 0.25) {
                Text(verbatim: dash.currentLapTimeText)
                    .font(.system(size: unit * 0.66, weight: .black, design: .monospaced))
                    .foregroundStyle(dash.currentLapInvalid ? Color(red: 1, green: 0.4, blue: 0.4) : .white)
                Text(verbatim: dash.deltaToFrontText)
                    .font(.system(size: unit * 0.46, weight: .black, design: .monospaced))
                    .foregroundStyle(amber)
                    .padding(.horizontal, unit * 0.2)
                    .padding(.vertical, unit * 0.05)
                    .background(
                        RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                            .stroke(amber.opacity(0.5), lineWidth: 1.2)
                    )
            }

            ZStack {
                rpmArc
                VStack(spacing: -unit * 0.15) {
                    Text(verbatim: dash.gearLabel)
                        .font(.system(size: unit * 2.6, weight: .black, design: .monospaced))
                        .foregroundStyle(dash.shiftFlash ? Color(red: 0.45, green: 0.5, blue: 1.0) : .white)
                        .animation(.easeOut(duration: 0.08), value: dash.shiftFlash)
                    HStack(alignment: .firstTextBaseline, spacing: unit * 0.08) {
                        Text(verbatim: "\(dash.speedKPH)")
                            .font(.system(size: unit * 0.8, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("KM/H")
                            .font(.system(size: unit * 0.24, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    /// Devir yayi: 270 derecelik acik yay, sonuna dogru kirmiziya doner.
    private var rpmArc: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: unit * 0.2, lineCap: .round))
            Circle()
                .trim(from: 0, to: 0.75 * dash.rpmFraction)
                .stroke(
                    AngularGradient(colors: [Color(red: 1, green: 0.2, blue: 0.18), amber, green],
                                    center: .center, angle: .degrees(135)),
                    style: StrokeStyle(lineWidth: unit * 0.2, lineCap: .round)
                )
        }
        .rotationEffect(.degrees(135))
        .padding(unit * 0.15)
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Sag blok

    private var rightBlock: some View {
        HStack(spacing: unit * 0.22) {
            batteryBar
            VStack(alignment: .leading, spacing: unit * 0.12) {
                VStack(alignment: .leading, spacing: -unit * 0.04) {
                    Text(verbatim: "\(Int(dash.ersFraction * 100))%")
                        .font(.system(size: unit * 0.7, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(dash.ersModeText)
                        .font(.system(size: unit * 0.26, weight: .heavy, design: .monospaced))
                        .foregroundStyle(cyan)
                }
                chip(text: dash.overtakeActive ? "OVERTAKE" : "OT READY",
                     active: dash.overtakeActive, ready: dash.overtakeAvailable, color: green)
                chip(text: dash.aeroStraightMode ? "AERO Z" : "AERO X",
                     active: dash.aeroStraightMode, ready: dash.aeroAvailable,
                     color: Color(red: 0.24, green: 0.78, blue: 1.0))
                if dash.pitLimiterOn {
                    chip(text: "LIMITER", active: true, ready: true,
                         color: Color(red: 1, green: 0.3, blue: 0.3))
                }
                Spacer(minLength: 0)
                HStack(spacing: unit * 0.18) {
                    readout(value: "P\(max(dash.carPosition, 1))", caption: "LAP \(dash.currentLapNum)",
                            tint: .white)
                    readout(value: String(format: "%.1f", dash.fuelRemainingLaps), caption: "FUEL",
                            tint: dash.fuelRemainingLaps < 0 ? Color(red: 1, green: 0.35, blue: 0.3) : .white)
                }
            }
        }
        .frame(width: unit * 4.4)
    }

    private var batteryBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.3, blue: 0.2), amber, green],
                                         startPoint: .bottom, endPoint: .top))
                    .frame(height: geo.size.height * dash.ersFraction)
            }
        }
        .frame(width: unit * 0.55)
        .padding(.vertical, unit * 0.1)
    }

    private func readout(value: String, caption: String, tint: Color) -> some View {
        VStack(spacing: -unit * 0.04) {
            Text(verbatim: value)
                .font(.system(size: unit * 0.58, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.system(size: unit * 0.22, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, unit * 0.08)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.12, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
    }

    private func chip(text: String, active: Bool, ready: Bool, color: Color) -> some View {
        Text(text)
            .font(.system(size: unit * 0.28, weight: .black, design: .monospaced))
            .foregroundStyle(active ? .black : (ready ? color : Color.white.opacity(0.2)))
            .padding(.horizontal, unit * 0.22)
            .padding(.vertical, unit * 0.1)
            .background(
                RoundedRectangle(cornerRadius: unit * 0.12, style: .continuous)
                    .fill(active ? color : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: unit * 0.12, style: .continuous)
                    .stroke(ready ? color.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1.2)
            )
    }
}
