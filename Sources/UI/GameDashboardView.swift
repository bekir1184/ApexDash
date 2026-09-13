import SwiftUI

/// F1 26'nin kokpit icindeki direksiyon ekraninin birebir taklidi:
/// koyu lacivert zemin, ince ayrac cizgileri, sol ustte hiz, ust ortada tur
/// suresi ile delta, ortada dev vites, yanlarda tur ve pozisyon, altta dort
/// kose lastik sicakligi ve segmentli ERS bandi.
struct GameDashboardView: View {
    let dash: DashboardModel
    let unit: CGFloat

    private let panel = Color(red: 0.11, green: 0.14, blue: 0.18)
    private let line = Color.white.opacity(0.32)
    private let cyan = Color(red: 0.24, green: 0.87, blue: 0.78)
    private let amber = Color(red: 0.92, green: 0.84, blue: 0.29)
    private let deltaRed = Color(red: 0.91, green: 0.29, blue: 0.26)

    var body: some View {
        VStack(spacing: unit * 0.22) {
            revStrip
            screen
        }
    }

    // MARK: - Direksiyon govdesindeki yuvarlak LED seridi

    private var revStrip: some View {
        HStack(spacing: unit * 0.13) {
            ForEach(0..<15, id: \.self) { index in
                let lit = dash.revLightsBits & (1 << UInt16(index)) != 0
                Circle()
                    .fill(lit ? ledColor(index) : Color.white.opacity(0.07))
                    .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1))
                    .shadow(color: lit ? ledColor(index).opacity(0.8) : .clear, radius: unit * 0.12)
            }
        }
        .frame(height: unit * 0.42)
    }

    private func ledColor(_ index: Int) -> Color {
        switch index {
        case 0..<5: return Color(red: 0.98, green: 0.98, blue: 0.98)
        case 5..<10: return Color(red: 1.0, green: 0.24, blue: 0.2)
        default: return Color(red: 0.55, green: 0.4, blue: 1.0)
        }
    }

    // MARK: - Ekran

    private var screen: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Rectangle().fill(panel)
                GameScreenLines().stroke(line, lineWidth: 1.2)

                // Sol ust: hiz
                cell(x: 0, y: 0, w: 0.26, h: 0.30, in: geo) {
                    VStack(spacing: 0) {
                        Text(verbatim: "\(dash.speedKPH)")
                            .font(Typeface.digits(h * 0.16, .bold))
                            .foregroundStyle(.white)
                        Text("KPH")
                            .font(Typeface.digits(h * 0.065, .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                // Ust orta: tur suresi ve delta
                cell(x: 0.26, y: 0, w: 0.48, h: 0.30, in: geo) {
                    VStack(spacing: h * 0.01) {
                        Text(verbatim: dash.currentLapTimeText)
                            .font(Typeface.digits(h * 0.135, .bold))
                            .foregroundStyle(.white)
                        Text(verbatim: dash.deltaToFrontText)
                            .font(Typeface.digits(h * 0.115, .bold))
                            .foregroundStyle(deltaRed)
                    }
                }

                // Sag ust: lastik yasi ve yakit
                cell(x: 0.74, y: 0, w: 0.26, h: 0.30, in: geo) {
                    VStack(spacing: 0) {
                        Text(verbatim: String(format: "%.1f", dash.fuelRemainingLaps))
                            .font(Typeface.digits(h * 0.13, .bold))
                            .foregroundStyle(dash.fuelRemainingLaps < 0 ? deltaRed : .white)
                        Text("FUEL")
                            .font(Typeface.digits(h * 0.065, .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                // Orta satir: tur, vites, pozisyon
                cell(x: 0, y: 0.30, w: 0.26, h: 0.32, in: geo) {
                    Text(verbatim: "L\(dash.currentLapNum)")
                        .font(Typeface.digits(h * 0.15, .bold))
                        .foregroundStyle(cyan)
                }
                cell(x: 0.26, y: 0.27, w: 0.48, h: 0.33, in: geo) {
                    Text(verbatim: dash.gearLabel)
                        .font(Typeface.digits(h * 0.38, .bold))
                        .foregroundStyle(.white)
                }
                cell(x: 0.74, y: 0.30, w: 0.26, h: 0.32, in: geo) {
                    Text(verbatim: "P\(max(dash.carPosition, 1))")
                        .font(Typeface.digits(h * 0.15, .bold))
                        .foregroundStyle(cyan)
                }

                // Sol alt: sol taraf lastikleri (FL, RL)
                cell(x: 0, y: 0.60, w: 0.26, h: 0.19, in: geo, alignment: .trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        tyreLabel(index: 2, height: h)
                        tyreLabel(index: 0, height: h)
                    }
                }

                // Sag alt: sag taraf lastikleri (FR, RR)
                cell(x: 0.74, y: 0.60, w: 0.26, h: 0.19, in: geo, alignment: .leading) {
                    VStack(alignment: .leading, spacing: 0) {
                        tyreLabel(index: 3, height: h)
                        tyreLabel(index: 1, height: h)
                    }
                }

                // Orta: devir bari
                revBar(width: w * 0.42, height: h * 0.075)
                    .position(x: w * 0.5, y: h * 0.695)

                // Alt: ERS bandi
                ersBand(width: w * 0.97, height: h * 0.15)
                    .position(x: w * 0.5, y: h * 0.885)
            }
        }
    }

    private func tyreLabel(index: Int, height: CGFloat) -> some View {
        let temp = dash.tyreSurfaceTemps.indices.contains(index) ? dash.tyreSurfaceTemps[index] : 0
        return Text(verbatim: "\(temp)°C")
            .font(Typeface.digits(height * 0.085, .bold))
            .foregroundStyle(temp == 0 ? Color.white.opacity(0.3) : TempScale.tyre(temp))
    }

    private func revBar(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Color(red: 0.36, green: 0.11, blue: 0.12))
            Rectangle()
                .fill(dash.shiftFlash ? Color.white : Color(red: 0.95, green: 0.23, blue: 0.2))
                .frame(width: width * dash.rpmFraction)
        }
        .frame(width: width, height: height)
        .overlay(Rectangle().stroke(line, lineWidth: 1.2))
    }

    /// Yesil-sari segmentli ERS bandi, ortasinda simsek ve yuzde.
    private func ersBand(width: CGFloat, height: CGFloat) -> some View {
        let segments = 28
        let lit = Int((dash.ersFraction * Double(segments)).rounded())
        return ZStack {
            HStack(spacing: 1) {
                ForEach(0..<segments, id: \.self) { index in
                    Rectangle()
                        .fill(index < lit ? ersColor(index: index, of: segments)
                                          : Color.white.opacity(0.06))
                }
            }
            Text(verbatim: "⚡\(Int(dash.ersFraction * 100))%")
                .font(Typeface.digits(height * 0.62, .heavy))
                .foregroundStyle(deltaRed)
                .shadow(color: .black.opacity(0.7), radius: 2)
        }
        .frame(width: width, height: height)
        .overlay(Rectangle().stroke(line, lineWidth: 1.2))
    }

    private func ersColor(index: Int, of total: Int) -> Color {
        Double(index) / Double(total) < 0.5
            ? Color(red: 0.55, green: 0.85, blue: 0.16)
            : Color(red: 0.94, green: 0.92, blue: 0.09)
    }

    /// Oransal yerlesim yardimcisi.
    private func cell<Content: View>(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                                     in geo: GeometryProxy,
                                     alignment: Alignment = .center,
                                     @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, geo.size.width * 0.015)
            .frame(width: geo.size.width * w, height: geo.size.height * h, alignment: alignment)
            .position(x: geo.size.width * (x + w / 2), y: geo.size.height * (y + h / 2))
    }
}

/// Oyundaki ekrani bolen ince ayrac cizgileri.
private struct GameScreenLines: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        // Ust satirin altindaki yatay ayraclar (orta bosluk birakilir)
        path.move(to: CGPoint(x: 0, y: h * 0.30));      path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.30))
        path.move(to: CGPoint(x: w * 0.74, y: h * 0.30)); path.addLine(to: CGPoint(x: w, y: h * 0.30))

        // Ust kutulari ayiran dikey cizgiler
        path.move(to: CGPoint(x: w * 0.26, y: 0));      path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.30))
        path.move(to: CGPoint(x: w * 0.74, y: 0));      path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.30))

        // Alt kose kutulari
        path.move(to: CGPoint(x: 0, y: h * 0.60));      path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.60))
        path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.79))
        path.move(to: CGPoint(x: w, y: h * 0.60));      path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.60))
        path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.79))

        return path
    }
}
