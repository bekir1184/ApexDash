import SwiftUI

/// Eski usul tek renkli segment gosterge paneli: kehribar rengi rakamlar,
/// arkada sonmus segmentlerin hayaleti.
struct SegmentDashboardView: View {
    let dash: DashboardModel
    let unit: CGFloat

    private let amber = Color(red: 1.0, green: 0.66, blue: 0.09)

    var body: some View {
        VStack(spacing: unit * 0.35) {
            HStack(alignment: .top, spacing: unit * 0.4) {
                stat(title: "SPEED", value: "\(dash.speedKPH)", ghost: "888", suffix: "KM/H")
                Spacer(minLength: 0)
                gearBlock
                Spacer(minLength: 0)
                stat(title: "LAP", value: dash.currentLapTimeText, ghost: "8:88.888", suffix: nil)
            }
            .frame(maxHeight: .infinity)

            rpmLadder

            HStack(spacing: unit * 0.25) {
                tempCell(label: "FL", tyre: temp(2), brake: brake(2))
                tempCell(label: "FR", tyre: temp(3), brake: brake(3))
                statusCell
                tempCell(label: "RL", tyre: temp(0), brake: brake(0))
                tempCell(label: "RR", tyre: temp(1), brake: brake(1))
            }
        }
        .padding(unit * 0.3)
        .background(Color(red: 0.03, green: 0.02, blue: 0.0))
    }

    private func temp(_ index: Int) -> Int {
        dash.tyreSurfaceTemps.indices.contains(index) ? dash.tyreSurfaceTemps[index] : 0
    }

    private func brake(_ index: Int) -> Int {
        dash.brakeTemps.indices.contains(index) ? dash.brakeTemps[index] : 0
    }

    private var gearBlock: some View {
        ZStack {
            Text(verbatim: "8")
                .foregroundStyle(amber.opacity(0.09))
            Text(verbatim: dash.gearLabel)
                .foregroundStyle(amber)
                .shadow(color: amber.opacity(0.55), radius: unit * 0.3)
        }
        .font(.system(size: unit * 3.6, weight: .black, design: .monospaced))
    }

    private func stat(title: String, value: String, ghost: String, suffix: String?) -> some View {
        VStack(alignment: .leading, spacing: unit * 0.06) {
            Text(title)
                .font(.system(size: unit * 0.26, weight: .heavy, design: .monospaced))
                .foregroundStyle(amber.opacity(0.55))
                .tracking(3)
            ZStack(alignment: .leading) {
                Text(verbatim: ghost)
                    .foregroundStyle(amber.opacity(0.09))
                Text(verbatim: value)
                    .foregroundStyle(amber)
            }
            .font(.system(size: unit * 0.95, weight: .black, design: .monospaced))
            if let suffix {
                Text(suffix)
                    .font(.system(size: unit * 0.24, weight: .heavy, design: .monospaced))
                    .foregroundStyle(amber.opacity(0.45))
            }
        }
    }

    private var rpmLadder: some View {
        GeometryReader { geo in
            let count = 30
            let spacing = geo.size.width * 0.004
            let width = (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            let lit = Int((dash.rpmFraction * Double(count)).rounded())
            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { index in
                    Rectangle()
                        .fill(index < lit ? amber : amber.opacity(0.1))
                        .frame(width: width)
                }
            }
        }
        .frame(height: unit * 0.42)
    }

    private func tempCell(label: String, tyre: Int, brake: Int) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: unit * 0.22, weight: .heavy, design: .monospaced))
                .foregroundStyle(amber.opacity(0.5))
            Text(verbatim: "\(tyre)")
                .font(.system(size: unit * 0.5, weight: .black, design: .monospaced))
                .foregroundStyle(amber)
            Text(verbatim: "\(brake)")
                .font(.system(size: unit * 0.28, weight: .bold, design: .monospaced))
                .foregroundStyle(amber.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, unit * 0.1)
        .overlay(Rectangle().stroke(amber.opacity(0.3), lineWidth: 1))
    }

    private var statusCell: some View {
        VStack(spacing: unit * 0.04) {
            Text(dash.overtakeActive ? "OVERTAKE" : (dash.overtakeAvailable ? "OT READY" : "OT --"))
                .foregroundStyle(dash.overtakeActive ? Color.black : amber)
                .padding(.horizontal, unit * 0.1)
                .background(dash.overtakeActive ? amber : Color.clear)
            Text(dash.aeroStraightMode ? "AERO Z" : "AERO X")
                .foregroundStyle(amber.opacity(dash.aeroAvailable ? 1 : 0.35))
            Text(verbatim: "P\(max(dash.carPosition, 1)) · LAP \(dash.currentLapNum)")
                .foregroundStyle(amber.opacity(0.55))
        }
        .font(.system(size: unit * 0.26, weight: .black, design: .monospaced))
        .frame(maxWidth: .infinity)
        .padding(.vertical, unit * 0.1)
        .overlay(Rectangle().stroke(amber.opacity(0.3), lineWidth: 1))
    }
}
