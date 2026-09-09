import SwiftUI

/// Yayin grafiklerindeki mavi HUD: ortada yuvarlak hiz gostergesi, iki yanda
/// onu saracak sekilde egilmis segment sutunlari, solda rakip plakalari,
/// sagda aktif aero, vites siralamasi ve devir cetveli.
struct BroadcastDashboardView: View {
    let dash: DashboardModel
    let unit: CGFloat

    private let panel = Color(red: 0.05, green: 0.12, blue: 0.19)
    private let edge = Color(red: 0.35, green: 0.78, blue: 0.95)
    private let ink = Color(red: 0.93, green: 0.97, blue: 1.0)
    private let green = Color(red: 0.22, green: 0.92, blue: 0.42)

    private var mph: Int { Int(Double(dash.speedKPH) * 0.621371) }

    var body: some View {
        HStack(spacing: unit * 0.18) {
            namePlates

            // Yanlar daireyi saracak sekilde disa dogru egilir ve alcalir.
            column(label: "BRAKE", fraction: Double(dash.brake),
                   tint: Color(red: 1.0, green: 0.35, blue: 0.32), segments: 8)
                .rotationEffect(.degrees(-11))
                .offset(y: unit * 0.62)
            column(label: "RECHARGE", fraction: rechargeFraction, tint: edge, segments: 10)
                .rotationEffect(.degrees(-5))
                .offset(y: unit * 0.2)

            speedDial

            column(label: "DEPLOY", fraction: deployFraction, tint: green, segments: 10)
                .rotationEffect(.degrees(5))
                .offset(y: unit * 0.2)
            column(label: "THROTTLE", fraction: Double(dash.throttle), tint: green, segments: 8)
                .rotationEffect(.degrees(11))
                .offset(y: unit * 0.62)

            rightPanel
        }
        .padding(.horizontal, unit * 0.25)
    }

    /// Sutunlar gercek ERS verisinden gelir: tur icinde toplanan ve harcanan
    /// enerjinin tur limitine orani. Limit gelmemisse deploy moduna dusulur.
    private var deployFraction: Double {
        dash.ersHarvestLimitPerLap > 0 ? dash.deployedFraction
                                       : min(Double(dash.ersDeployMode) / 3, 1)
    }

    private var rechargeFraction: Double { dash.harvestFraction }

    // MARK: - Ortadaki yuvarlak gosterge

    private var speedDial: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                caption("KM/H")
                Text(verbatim: "\(dash.speedKPH)")
                    .font(.system(size: unit * 1.05, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                caption("BOOST")
                overtakePill
                    .padding(.horizontal, unit * 0.25)

                Text(verbatim: "\(mph)")
                    .font(.system(size: unit * 1.05, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                caption("MPH")
            }
            .padding(unit * 0.3)
            .frame(width: unit * 4.1, height: unit * 4.1)
            .background(
                Circle().fill(
                    RadialGradient(colors: [panel.opacity(0.98), panel.opacity(0.72)],
                                   center: .center, startRadius: 0, endRadius: unit * 2.1)
                )
            )
            .overlay {
                ShiftFlashOverlay(active: dash.shiftFlash, color: edge).clipShape(Circle())
            }
            .overlay(Circle().stroke(edge.opacity(0.8), lineWidth: unit * 0.05))
            .shadow(color: edge.opacity(0.3), radius: unit * 0.45)

            batteryPill
                .offset(y: unit * 0.34)
        }
    }

    private var overtakePill: some View {
        Text(dash.overtakeActive ? "OVERTAKE" : (dash.overtakeAvailable ? "OVERTAKE" : "OVERTAKE"))
            .font(.system(size: unit * 0.28, weight: .heavy, design: .rounded))
            .foregroundStyle(dash.overtakeActive ? .black : ink.opacity(dash.overtakeAvailable ? 0.9 : 0.3))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            .padding(.vertical, unit * 0.05)
            .background(
                RoundedRectangle(cornerRadius: unit * 0.08, style: .continuous)
                    .fill(dash.overtakeActive ? green : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: unit * 0.08, style: .continuous)
                    .stroke(green.opacity(dash.overtakeAvailable || dash.overtakeActive ? 0.9 : 0.25),
                            lineWidth: 1.5)
            )
    }

    private var batteryPill: some View {
        HStack(spacing: unit * 0.1) {
            Image(systemName: "bolt.fill")
                .font(.system(size: unit * 0.22, weight: .black))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.4))
                    Capsule().fill(edge).frame(width: geo.size.width * dash.ersFraction)
                }
            }
            .frame(height: unit * 0.16)
        }
        .foregroundStyle(ink)
        .frame(width: unit * 1.8)
        .padding(.horizontal, unit * 0.12)
        .padding(.vertical, unit * 0.07)
        .background(Capsule().fill(panel))
        .overlay(Capsule().stroke(edge.opacity(0.8), lineWidth: 1.2))
    }

    // MARK: - Yan sutunlar

    private func column(label: String, fraction: Double, tint: Color, segments: Int) -> some View {
        HStack(spacing: unit * 0.07) {
            Text(label)
                .font(.system(size: unit * 0.19, weight: .heavy, design: .rounded))
                .foregroundStyle(ink.opacity(0.75))
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .frame(width: unit * 0.26)

            VStack(spacing: unit * 0.045) {
                let lit = Int((min(max(fraction, 0), 1) * Double(segments)).rounded())
                ForEach(0..<segments, id: \.self) { index in
                    RoundedRectangle(cornerRadius: unit * 0.03, style: .continuous)
                        .fill(segments - index <= lit ? tint : Color.white.opacity(0.07))
                        .frame(height: unit * 0.17)
                }
            }
            .frame(width: unit * 0.36)
        }
        .padding(unit * 0.11)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.5, style: .continuous)
                .fill(panel.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.5, style: .continuous)
                .stroke(edge.opacity(0.55), lineWidth: 1.5)
        )
    }

    // MARK: - Rakip plakalari

    /// Yayindaki gibi mavi, egik plakalar: ustte onundeki, altta arkandaki.
    private var namePlates: some View {
        VStack(alignment: .leading, spacing: unit * 0.14) {
            plate(for: dash.driverAhead)
            plate(for: dash.driverBehind)
        }
        .frame(width: unit * 3.0, alignment: .leading)
    }

    @ViewBuilder
    private func plate(for rival: Rival?) -> some View {
        if let rival {
            HStack(spacing: unit * 0.14) {
                Text(verbatim: "\(rival.position)")
                    .font(.system(size: unit * 0.32, weight: .black, design: .rounded))
                    .foregroundStyle(ink.opacity(0.7))
                Text(verbatim: rival.name)
                    .font(.system(size: unit * 0.32, weight: .black, design: .rounded))
                    .foregroundStyle(edge)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, unit * 0.22)
            .padding(.vertical, unit * 0.1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Parallelogram(slant: unit * 0.24)
                    .fill(LinearGradient(colors: [panel.opacity(0.95), panel.opacity(0.4)],
                                         startPoint: .leading, endPoint: .trailing))
            )
            .overlay(Parallelogram(slant: unit * 0.24).stroke(edge.opacity(0.8), lineWidth: 1.5))
        } else {
            Color.clear.frame(height: unit * 0.6)
        }
    }

    // MARK: - Sag panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: unit * 0.2) {
            HStack(spacing: unit * 0.16) {
                Text("ACTIVE\nAERO")
                    .font(.system(size: unit * 0.23, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink.opacity(0.75))
                Text(verbatim: "//")
                    .font(.system(size: unit * 0.48, weight: .black, design: .rounded))
                    .foregroundStyle(dash.aeroStraightMode ? green : ink.opacity(0.22))
            }

            gears
            rpmScale
        }
        .padding(unit * 0.24)
        .frame(width: unit * 4.3)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.4, style: .continuous)
                .fill(panel.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.4, style: .continuous)
                .stroke(edge.opacity(0.6), lineWidth: 1.5)
        )
    }

    private var gears: some View {
        HStack(alignment: .firstTextBaseline, spacing: unit * 0.1) {
            ForEach(gearLabels, id: \.self) { label in
                let selected = label == dash.gearLabel
                Text(verbatim: label)
                    .font(.system(size: selected ? unit * 0.6 : unit * 0.32,
                                  weight: selected ? .black : .semibold, design: .rounded))
                    .foregroundStyle(selected ? ink : ink.opacity(0.28))
            }
            Text("GEARS")
                .font(.system(size: unit * 0.19, weight: .heavy, design: .rounded))
                .foregroundStyle(ink.opacity(0.55))
        }
    }

    private var gearLabels: [String] {
        ["N"] + (1...max(dash.maxGears, 8)).map(String.init)
    }

    /// Devir cetveli: tek renk mavi cizgi, ustunde dolan parlak bant.
    private var rpmScale: some View {
        VStack(alignment: .leading, spacing: unit * 0.06) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(edge.opacity(0.18))
                    Capsule()
                        .fill(dash.shiftFlash ? ink : edge)
                        .frame(width: geo.size.width * dash.rpmFraction)
                }
            }
            .frame(height: unit * 0.16)

            HStack(spacing: 0) {
                ForEach(Array(stride(from: 0, through: 15, by: 3)), id: \.self) { value in
                    Text(verbatim: "\(value)")
                        .font(.system(size: unit * 0.17, weight: .heavy, design: .rounded))
                        .foregroundStyle(ink.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(verbatim: "RPM x1000")
                    .font(.system(size: unit * 0.17, weight: .heavy, design: .rounded))
                    .foregroundStyle(edge.opacity(0.8))
                    .fixedSize()
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: unit * 0.22, weight: .heavy, design: .rounded))
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
