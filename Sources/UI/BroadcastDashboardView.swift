import SwiftUI

/// Yayin grafiklerindeki mavi HUD: ortada kalkan bicimli hiz gostergesi,
/// iki yanda gaz/fren ve ERS sutunlari, sagda aktif aero, vites siralamasi
/// ve devir cetveli.
struct BroadcastDashboardView: View {
    let dash: DashboardModel
    let unit: CGFloat

    private let panel = Color(red: 0.05, green: 0.12, blue: 0.19)
    private let edge = Color(red: 0.35, green: 0.78, blue: 0.95)
    private let ink = Color(red: 0.93, green: 0.97, blue: 1.0)
    private let green = Color(red: 0.22, green: 0.92, blue: 0.42)

    private var mph: Int { Int(Double(dash.speedKPH) * 0.621371) }

    var body: some View {
        HStack(spacing: unit * 0.2) {
            namePlates

            segmentColumn(label: "BRAKE", fraction: Double(dash.brake),
                          tint: Color(red: 1.0, green: 0.35, blue: 0.32))
            segmentColumn(label: "RECHARGE", fraction: rechargeFraction, tint: edge)

            shield
                .frame(maxWidth: .infinity)

            segmentColumn(label: "DEPLOY", fraction: deployFraction, tint: green)
            segmentColumn(label: "THROTTLE", fraction: Double(dash.throttle), tint: green)

            rightPanel
        }
        .padding(.horizontal, unit * 0.3)
        .padding(.vertical, unit * 0.2)
    }

    /// Sutunlar gercek ERS verisinden gelir: tur icinde toplanan ve harcanan
    /// enerjinin tur limitine orani. Limit gelmemisse deploy moduna dusulur.
    private var deployFraction: Double {
        dash.ersHarvestLimitPerLap > 0 ? dash.deployedFraction
                                       : min(Double(dash.ersDeployMode) / 3, 1)
    }

    private var rechargeFraction: Double {
        dash.harvestFraction
    }

    // MARK: - Ortadaki kalkan

    private var shield: some View {
        VStack(spacing: unit * 0.02) {
            caption("KM/H")
            Text(verbatim: "\(dash.speedKPH)")
                .font(.system(size: unit * 1.25, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            caption("BOOST")
            overtakePill

            Text(verbatim: "\(mph)")
                .font(.system(size: unit * 1.25, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            caption("MPH")

            batteryPill
                .padding(.top, unit * 0.1)
        }
        .padding(.horizontal, unit * 0.5)
        .padding(.vertical, unit * 0.25)
        .background(
            RoundedRectangle(cornerRadius: unit * 1.4, style: .continuous)
                .fill(
                    LinearGradient(colors: [panel.opacity(0.95), panel.opacity(0.7)],
                                   startPoint: .top, endPoint: .bottom)
                )
        )
        .overlay {
            // Vites degistirme uyarisi yalnizca gostergenin icinde parlar.
            ShiftFlashOverlay(active: dash.shiftFlash, color: edge)
                .clipShape(RoundedRectangle(cornerRadius: unit * 1.4, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: unit * 1.4, style: .continuous)
                .stroke(edge.opacity(0.75), lineWidth: unit * 0.04)
        )
        .shadow(color: edge.opacity(0.25), radius: unit * 0.4)
    }

    private var overtakePill: some View {
        Text(dash.overtakeActive ? "OVERTAKE" : (dash.overtakeAvailable ? "OVERTAKE READY" : "OVERTAKE"))
            .font(.system(size: unit * 0.3, weight: .heavy, design: .rounded))
            .foregroundStyle(dash.overtakeActive ? .black : ink.opacity(dash.overtakeAvailable ? 0.9 : 0.35))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            .padding(.vertical, unit * 0.06)
            .background(
                RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                    .fill(dash.overtakeActive ? green : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: unit * 0.1, style: .continuous)
                    .stroke(green.opacity(dash.overtakeAvailable || dash.overtakeActive ? 0.9 : 0.25),
                            lineWidth: 1.5)
            )
    }

    private var batteryPill: some View {
        HStack(spacing: unit * 0.1) {
            Image(systemName: "bolt.fill")
                .font(.system(size: unit * 0.24, weight: .black))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.35))
                    Capsule().fill(edge)
                        .frame(width: geo.size.width * dash.ersFraction)
                }
            }
            .frame(height: unit * 0.18)
        }
        .foregroundStyle(ink)
        .frame(width: unit * 2.2)
        .padding(.horizontal, unit * 0.14)
        .padding(.vertical, unit * 0.08)
        .background(Capsule().fill(edge.opacity(0.22)))
        .overlay(Capsule().stroke(edge.opacity(0.7), lineWidth: 1.2))
    }

    // MARK: - Yan sutunlar

    /// Dort sutun da ayni olcude: dikey yazi + on segment.
    private func segmentColumn(label: String, fraction: Double, tint: Color) -> some View {
        HStack(spacing: unit * 0.08) {
            Text(label)
                .font(.system(size: unit * 0.2, weight: .heavy, design: .rounded))
                .foregroundStyle(ink.opacity(0.75))
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .frame(width: unit * 0.28)

            VStack(spacing: unit * 0.045) {
                let segments = 10
                let lit = Int((min(max(fraction, 0), 1) * Double(segments)).rounded())
                ForEach(0..<segments, id: \.self) { index in
                    RoundedRectangle(cornerRadius: unit * 0.03, style: .continuous)
                        .fill(segments - index <= lit ? tint : Color.white.opacity(0.07))
                        .frame(height: unit * 0.17)
                }
            }
            .frame(width: unit * 0.38)
        }
        .padding(unit * 0.12)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.18, style: .continuous)
                .fill(panel.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.18, style: .continuous)
                .stroke(edge.opacity(0.55), lineWidth: 1.5)
        )
    }

    // MARK: - Isim plakalari

    /// Yayin grafigindeki gibi egik plakalar: ustte onundeki, altta arkandaki.
    private var namePlates: some View {
        VStack(alignment: .leading, spacing: unit * 0.14) {
            plate(for: dash.driverAhead)
            plate(for: dash.driverBehind)
        }
        .frame(width: unit * 3.1, alignment: .leading)
    }

    @ViewBuilder
    private func plate(for rival: Rival?) -> some View {
        if let rival {
            let colour = Color(red: rival.red, green: rival.green, blue: rival.blue)
            HStack(spacing: unit * 0.14) {
                Text(verbatim: "\(rival.position)")
                    .font(.system(size: unit * 0.34, weight: .black, design: .rounded))
                    .foregroundStyle(ink.opacity(0.8))
                Text(verbatim: rival.name)
                    .font(.system(size: unit * 0.34, weight: .black, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, unit * 0.22)
            .padding(.vertical, unit * 0.1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Parallelogram(slant: unit * 0.22)
                    .fill(
                        LinearGradient(colors: [colour.opacity(0.55), colour.opacity(0.12)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
            )
            .overlay(
                Parallelogram(slant: unit * 0.22)
                    .stroke(colour.opacity(0.9), lineWidth: 1.5)
            )
        } else {
            Color.clear.frame(height: unit * 0.6)
        }
    }

    // MARK: - Sag panel    // MARK: - Sag panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: unit * 0.18) {
            HStack(spacing: unit * 0.16) {
                Text("ACTIVE\nAERO")
                    .font(.system(size: unit * 0.24, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink.opacity(0.75))
                Text(verbatim: "//")
                    .font(.system(size: unit * 0.5, weight: .black, design: .rounded))
                    .foregroundStyle(dash.aeroStraightMode ? green : ink.opacity(0.25))
            }

            gears
            rpmScale
        }
        .padding(unit * 0.24)
        .frame(width: unit * 4.6)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
                .fill(panel.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
                .stroke(edge.opacity(0.6), lineWidth: 1.5)
        )
    }

    private var gears: some View {
        HStack(alignment: .firstTextBaseline, spacing: unit * 0.1) {
            ForEach(gearLabels, id: \.self) { label in
                let selected = label == dash.gearLabel
                Text(verbatim: label)
                    .font(.system(size: selected ? unit * 0.62 : unit * 0.34,
                                  weight: selected ? .black : .semibold, design: .rounded))
                    .foregroundStyle(selected ? ink : ink.opacity(0.3))
            }
            Text("GEARS")
                .font(.system(size: unit * 0.2, weight: .heavy, design: .rounded))
                .foregroundStyle(ink.opacity(0.55))
        }
    }

    private var gearLabels: [String] {
        ["N"] + (1...max(dash.maxGears, 8)).map(String.init)
    }

    /// Devir cetveli: x1000 olcekli ince cizgiler ve dolan bant.
    private var rpmScale: some View {
        VStack(alignment: .leading, spacing: unit * 0.06) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: unit * 0.05, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                    RoundedRectangle(cornerRadius: unit * 0.05, style: .continuous)
                        .fill(
                            LinearGradient(colors: [edge, green, Color(red: 1, green: 0.35, blue: 0.3)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * dash.rpmFraction)
                }
            }
            .frame(height: unit * 0.22)

            HStack(spacing: 0) {
                ForEach(Array(stride(from: 0, through: 15, by: 3)), id: \.self) { value in
                    Text(verbatim: "\(value)")
                        .font(.system(size: unit * 0.18, weight: .heavy, design: .rounded))
                        .foregroundStyle(ink.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(verbatim: "RPM x1000")
                    .font(.system(size: unit * 0.18, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink.opacity(0.55))
                    .fixedSize()
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: unit * 0.24, weight: .heavy, design: .rounded))
            .foregroundStyle(ink.opacity(0.6))
            .tracking(2)
    }
}


/// Yayin grafiklerindeki egik plaka bicimi.
struct Parallelogram: Shape {
    var slant: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + slant, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - slant, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
