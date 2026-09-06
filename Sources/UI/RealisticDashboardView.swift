import SwiftUI

/// Gercek F1 direksiyonlarindaki (Bosch / McLaren Applied tipi) ekranin
/// taklidi: zeytin yesili LCD zemin, ustte koyu yazili durum bandi, solda hiz,
/// ortada dev vites ve altinda batarya, sagda yakit, altta lastik sicakliklari.
struct RealisticDashboardView: View {
    let dash: DashboardModel
    let unit: CGFloat

    private let lcd = Color(red: 0.12, green: 0.13, blue: 0.09)
    private let ink = Color(red: 0.87, green: 0.90, blue: 0.66)
    private let band = Color(red: 0.62, green: 0.65, blue: 0.24)
    private let dim = Color(red: 0.55, green: 0.58, blue: 0.40)
    private let alert = Color(red: 0.95, green: 0.42, blue: 0.16)

    private var rule: Color { ink.opacity(0.28) }

    var body: some View {
        VStack(spacing: 0) {
            wheelLeds
                .padding(.bottom, unit * 0.16)

            VStack(spacing: 0) {
                statusBand
                Divider().overlay(rule)
                mainRow
                Divider().overlay(rule)
                bottomRow
                ersBar
            }
            .background(lcd)
            .overlay(Rectangle().stroke(rule, lineWidth: 1))
        }
    }

    // MARK: - Direksiyon govdesindeki LED'ler

    /// Fotograftaki gibi solda yesil, sagda mavi kume.
    private var wheelLeds: some View {
        HStack(spacing: unit * 0.16) {
            ForEach(0..<10, id: \.self) { index in
                let lit = dash.rpmFraction * 10 > Double(index)
                let color = index < 5
                    ? Color(red: 0.24, green: 0.92, blue: 0.35)
                    : Color(red: 0.35, green: 0.55, blue: 1.0)
                Circle()
                    .fill(lit || dash.shiftFlash ? color : Color.white.opacity(0.06))
                    .frame(width: unit * 0.26, height: unit * 0.26)
                    .shadow(color: lit ? color.opacity(0.8) : .clear, radius: unit * 0.1)
            }
        }
    }

    // MARK: - Ust bant

    /// Sol: ERS modu. Orta: en oncelikli uyari. Sag: tur suresi.
    private var statusBand: some View {
        HStack(spacing: 0) {
            Text(dash.ersModeText)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(bandStatus)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(verbatim: dash.currentLapTimeText)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: unit * 0.42, weight: .heavy, design: .monospaced))
        .foregroundStyle(.black)
        .padding(.horizontal, unit * 0.3)
        .padding(.vertical, unit * 0.1)
        .frame(maxWidth: .infinity)
        .background(dash.pitLimiterOn ? alert : band)
    }

    private var bandStatus: String {
        if dash.pitLimiterOn { return "PIT LIMITER" }
        if dash.aeroStraightMode { return "STRAIGHT" }
        if dash.aeroAvailable { return "AERO READY" }
        return "LAP \(dash.currentLapNum)"
    }

    // MARK: - Ana satir

    private var mainRow: some View {
        HStack(spacing: 0) {
            value(text: "\(dash.speedKPH)", caption: "KPH")
                .frame(maxWidth: .infinity)

            Rectangle().fill(rule).frame(width: 1)

            VStack(spacing: -unit * 0.12) {
                Text(verbatim: dash.gearLabel)
                    .font(.system(size: unit * 2.9, weight: .black, design: .monospaced))
                    .foregroundStyle(dash.shiftFlash ? Color(red: 0.98, green: 1.0, blue: 0.85) : ink)
                    .animation(.easeOut(duration: 0.08), value: dash.shiftFlash)
                Text(verbatim: "\(Int(dash.ersFraction * 100))")
                    .font(.system(size: unit * 0.6, weight: .heavy, design: .monospaced))
                    .foregroundStyle(dim)
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(rule).frame(width: 1)

            value(text: String(format: "%.1f", dash.fuelRemainingLaps), caption: "FUEL",
                  tint: dash.fuelRemainingLaps < 0 ? alert : ink)
                .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    private func value(text: String, caption: String, tint: Color? = nil) -> some View {
        VStack(spacing: -unit * 0.06) {
            Text(verbatim: text)
                .font(.system(size: unit * 1.35, weight: .heavy, design: .monospaced))
                .foregroundStyle(tint ?? ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(caption)
                .font(.system(size: unit * 0.3, weight: .heavy, design: .monospaced))
                .foregroundStyle(dim)
        }
    }

    // MARK: - Alt satir

    private var bottomRow: some View {
        HStack(spacing: 0) {
            tyrePair(front: 2, rear: 0)
            Rectangle().fill(rule).frame(width: 1)
            VStack(spacing: -unit * 0.05) {
                Text(verbatim: dash.deltaToCarInFrontMS > 0 ? dash.deltaToFrontText : "--.--")
                    .font(.system(size: unit * 0.7, weight: .heavy, design: .monospaced))
                    .foregroundStyle(deltaTint)
                Text(verbatim: "P\(max(dash.carPosition, 1))  ·  L\(dash.currentLapNum)")
                    .font(.system(size: unit * 0.32, weight: .heavy, design: .monospaced))
                    .foregroundStyle(dim)
            }
            .frame(maxWidth: .infinity)
            Rectangle().fill(rule).frame(width: 1)
            tyrePair(front: 3, rear: 1)
        }
        .frame(height: unit * 1.5)
    }

    private var deltaTint: Color {
        switch dash.deltaTrend {
        case ..<0: return Color(red: 0.45, green: 0.92, blue: 0.4)
        case 1...: return alert
        default: return ink
        }
    }

    /// Fotograftaki gibi kucuk, etiketsiz sicaklik kumesi: ustte lastik, altta fren.
    private func tyrePair(front: Int, rear: Int) -> some View {
        VStack(spacing: unit * 0.06) {
            tyreLine(index: front, label: front == 2 ? "FL" : "FR")
            tyreLine(index: rear, label: rear == 0 ? "RL" : "RR")
        }
        .frame(maxWidth: .infinity)
    }

    private func tyreLine(index: Int, label: String) -> some View {
        let surface = dash.tyreSurfaceTemps.indices.contains(index) ? dash.tyreSurfaceTemps[index] : 0
        let brake = dash.brakeTemps.indices.contains(index) ? dash.brakeTemps[index] : 0
        return HStack(spacing: unit * 0.14) {
            Text(label)
                .font(.system(size: unit * 0.28, weight: .heavy, design: .monospaced))
                .foregroundStyle(dim)
            Text(verbatim: "\(surface)")
                .font(.system(size: unit * 0.46, weight: .heavy, design: .monospaced))
                .foregroundStyle(TempScale.tyre(surface))
            Text(verbatim: "\(brake)")
                .font(.system(size: unit * 0.32, weight: .heavy, design: .monospaced))
                .foregroundStyle(dim)
        }
    }

    /// Ekranin en altindaki ince batarya seridi.
    private var ersBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.black.opacity(0.5))
                Rectangle()
                    .fill(dash.ersFraction < 0.2 ? alert : band)
                    .frame(width: geo.size.width * dash.ersFraction)
            }
        }
        .frame(height: unit * 0.24)
    }
}
