import SwiftUI

/// The palette of real F1 wheel displays (Bosch / McLaren Applied style). With the pit
/// limiter on, the whole display turns yellow and the text dark, as in real cars in the pit
/// lane.
enum RealisticPalette {
    static let ground = Color(red: 0.055, green: 0.06, blue: 0.05)
    /// The wheel body around the display.
    static let bezel = Color(red: 0.075, green: 0.08, blue: 0.09)
    static let limiterGround = Color(red: 0.71, green: 0.75, blue: 0.18)

    static func ground(limiter: Bool) -> Color { limiter ? limiterGround : ground }
    static func ink(limiter: Bool) -> Color {
        limiter ? Color(red: 0.07, green: 0.08, blue: 0.03) : Color(red: 0.95, green: 0.96, blue: 0.90)
    }
    static func dim(limiter: Bool) -> Color {
        limiter ? Color(red: 0.07, green: 0.08, blue: 0.03).opacity(0.6)
                : Color(red: 0.58, green: 0.60, blue: 0.52)
    }
}

struct RealisticDashboardView: View {
    let dash: DashboardModel
    let unit: CGFloat

    private var limiter: Bool { dash.pitLimiterOn }
    private var ink: Color { RealisticPalette.ink(limiter: limiter) }
    private var dim: Color { RealisticPalette.dim(limiter: limiter) }
    private var rule: Color { ink.opacity(0.22) }
    private let alert = Color(red: 0.95, green: 0.42, blue: 0.16)

    var body: some View {
        VStack(spacing: unit * 0.16) {
            wheelLeds

            // The flag lights sit on the housing frame on both sides of the display, like
            // the rev strip above it.
            HStack(spacing: unit * 0.16) {
                sideLights
                screen
                sideLights
            }
        }
        // Wheel body: the frame around the display, carrying the LED strip.
        .padding(.horizontal, unit * 0.18)
        .padding(.vertical, unit * 0.22)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.42, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(red: 0.13, green: 0.14, blue: 0.15),
                                            RealisticPalette.bezel,
                                            Color(red: 0.04, green: 0.04, blue: 0.05)],
                                   startPoint: .top, endPoint: .bottom)
                )
                // Outer edge of the body: a chamfer, bright on top and dark below.
                .overlay(
                    RoundedRectangle(cornerRadius: unit * 0.42, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [Color.white.opacity(0.22),
                                                    Color.white.opacity(0.04),
                                                    Color.black.opacity(0.6)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: unit * 0.07
                        )
                )
                .shadow(color: .black.opacity(0.8), radius: unit * 0.3, y: unit * 0.1)
        )
        .padding(unit * 0.1)
    }

    private var screen: some View {
        VStack(spacing: 0) {
            topRow
            Rectangle().fill(rule).frame(height: 1)
            mainRow
            Rectangle().fill(rule).frame(height: 1)
            bottomRow
            SectorStrip(dash: dash, unit: unit, compact: true)
                .padding(.horizontal, unit * 0.12)
                .padding(.bottom, unit * 0.06)
            ersBar
        }
        .background(RealisticPalette.ground(limiter: limiter))
        .overlay { ShiftFlashOverlay(active: dash.shiftFlash) }
        .clipShape(RoundedRectangle(cornerRadius: unit * 0.12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.12, style: .continuous)
                .stroke(Color.black.opacity(0.9), lineWidth: unit * 0.1)
        )
    }

    // MARK: - Side warning lights

    /// The vertical clusters on both sides of the display show FIA flags. The green light
    /// flashes when the lap is invalid (not counted).
    private var sideLights: some View {
        TimelineView(.periodic(from: .now, by: 0.3)) { context in
            let phase = Int(context.date.timeIntervalSinceReferenceDate / 0.3) % 2 == 0
            let state = flagState
            VStack(spacing: unit * 0.26) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(state.color.opacity(state.blinking && !phase ? 0.12 : 1))
                        .frame(width: unit * 0.3, height: unit * 0.3)
                        .shadow(color: state.color.opacity(state.color == off ? 0 : 0.85),
                                radius: unit * 0.14)
                }
            }
            .frame(width: unit * 0.34)
            // The lights sit near the top of the display.
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, unit * 0.5)
        }
    }

    private var off: Color { Color.white.opacity(0.05) }

    /// Priority: yellow > blue > invalid lap (flashing green) > green > off.
    private var flagState: (color: Color, blinking: Bool) {
        switch dash.fiaFlag {
        case 3: return (Color(red: 1.0, green: 0.85, blue: 0.1), true)
        case 2: return (Color(red: 0.25, green: 0.5, blue: 1.0), true)
        default: break
        }
        let green = Color(red: 0.2, green: 0.92, blue: 0.3)
        if dash.currentLapInvalid { return (green, true) }
        if dash.fiaFlag == 1 { return (green, false) }
        return (off, false)
    }

    // MARK: - LEDs on the wheel body

    /// The rev strip on the frame: the same colour order as the other dashboards (green,
    /// red, purple), gapless and as wide as the display.
    private var wheelLeds: some View {
        HStack(spacing: 0) {
            ForEach(0..<15, id: \.self) { index in
                // Uses the game's own LED pattern: 15 bits, left to right.
                let lit = dash.revLightsBits & (1 << UInt16(index)) != 0
                let color = ledColor(index)
                Circle()
                    .fill(lit || dash.shiftFlash ? color : Color.white.opacity(0.05))
                    .frame(width: unit * 0.34, height: unit * 0.34)
                    .shadow(color: lit ? color.opacity(0.85) : .clear, radius: unit * 0.14)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, unit * 0.1)
    }

    private func ledColor(_ index: Int) -> Color {
        switch index {
        case 0..<5: return Color(red: 0.18, green: 0.92, blue: 0.32)
        case 5..<10: return Color(red: 1.0, green: 0.2, blue: 0.16)
        default: return Color(red: 0.5, green: 0.42, blue: 1.0)
        }
    }

    // MARK: - Top row: delta, status, lap time

    private var topRow: some View {
        HStack(spacing: 0) {
            Text(verbatim: dash.deltaToBestMS != nil ? dash.deltaToBestText
                                                     : (dash.deltaToCarInFrontMS > 0 ? dash.deltaToFrontText : "+0.000"))
                .foregroundStyle(limiter ? ink : deltaTint)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(status)
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(verbatim: dash.currentLapTimeText)
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: unit * 0.46, weight: .heavy, design: .monospaced))
        .padding(.horizontal, unit * 0.3)
        .padding(.vertical, unit * 0.08)
    }

    private var status: String {
        if limiter { return "PIT LIMITER" }
        if dash.aeroEngaged { return dash.usesDRS ? "DRS ON" : "STRAIGHT" }
        if dash.aeroReady { return dash.usesDRS ? "DRS READY" : "AERO READY" }
        return dash.ersModeText
    }

    private var deltaTint: Color {
        if let delta = dash.deltaToBestMS {
            if delta < -20 { return Color(red: 0.45, green: 0.92, blue: 0.4) }
            if delta > 20 { return alert }
            return ink
        }
        switch dash.deltaTrend {
        case ..<0: return Color(red: 0.45, green: 0.92, blue: 0.4)
        case 1...: return alert
        default: return ink
        }
    }

    // MARK: - Main row: speed, gear (battery below), fuel

    private var mainRow: some View {
        HStack(spacing: 0) {
            value(text: "\(dash.speedKPH)", caption: "KPH")
                .frame(maxWidth: .infinity)

            Rectangle().fill(rule).frame(width: 1)

            VStack(spacing: -unit * 0.12) {
                Text(verbatim: dash.gearLabel)
                    .font(.system(size: unit * 2.9, weight: .black, design: .monospaced))
                    .foregroundStyle(dash.shiftFlash && !limiter
                                     ? Color(red: 0.98, green: 1.0, blue: 0.85) : ink)
                    .animation(.easeOut(duration: 0.08), value: dash.shiftFlash)
                Text(verbatim: "\(Int(dash.ersFraction * 100))")
                    .font(.system(size: unit * 0.6, weight: .heavy, design: .monospaced))
                    .foregroundStyle(dim)
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(rule).frame(width: 1)

            value(text: String(format: "%.1f", dash.fuelRemainingLaps), caption: "FUEL",
                  tint: dash.fuelRemainingLaps < 0 && !limiter ? alert : ink)
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

    // MARK: - Bottom row: tyres and position

    private var bottomRow: some View {
        HStack(spacing: 0) {
            tyrePair(front: 2, rear: 0)
            Rectangle().fill(rule).frame(width: 1)
            VStack(spacing: -unit * 0.05) {
                Text(verbatim: "P\(max(dash.carPosition, 1))")
                    .font(.system(size: unit * 0.7, weight: .heavy, design: .monospaced))
                    .foregroundStyle(ink)
                Text(verbatim: "LAP \(dash.currentLapNum)")
                    .font(.system(size: unit * 0.32, weight: .heavy, design: .monospaced))
                    .foregroundStyle(dim)
            }
            .frame(maxWidth: .infinity)
            Rectangle().fill(rule).frame(width: 1)
            tyrePair(front: 3, rear: 1)
        }
        .frame(height: unit * 1.5)
    }

    /// Small temperature cluster: front/rear left on the left, front/rear right on the right.
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
                .foregroundStyle(limiter ? ink : TempScale.tyre(surface))
            Text(verbatim: "\(brake)")
                .font(.system(size: unit * 0.32, weight: .heavy, design: .monospaced))
                .foregroundStyle(dim)
        }
    }

    /// The thin battery strip at the very bottom.
    private var ersBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(ink.opacity(0.12))
                Rectangle()
                    .fill(dash.ersFraction < 0.2 ? alert : Color(red: 0.62, green: 0.85, blue: 0.2))
                    .frame(width: geo.size.width * dash.ersFraction)
            }
        }
        .frame(height: unit * 0.24)
    }
}
