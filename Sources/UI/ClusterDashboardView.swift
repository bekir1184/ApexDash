import SwiftUI

/// A modern sports car's digital instrument cluster: three round dials on black glass. RPM
/// on the left, speed and energy in the middle, G force on the right.
struct ClusterDashboardView: View {
    let dash: DashboardModel
    let unit: CGFloat

    var body: some View {
        GeometryReader { geo in
            // The timer pauses except during the shift warning; telemetry already redraws
            // the dashboard.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !dash.shiftFlash)) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                Canvas(rendersAsynchronously: false) { context, size in
                    ClusterHUD(dash: dash, size: size, time: phase).draw(in: &context)
                }
            }
        }
    }
}

struct ClusterHUD {
    let dash: DashboardModel
    let size: CGSize
    /// Time base of the shift warning animation.
    var time: TimeInterval = 0

    /// Warning pulse moving between 0 and 1.
    private var pulse: Double {
        guard dash.shiftFlash else { return 0 }
        return 0.5 + 0.5 * sin(time * 18)
    }
    let shiftRed = Color(red: 1.0, green: 0.16, blue: 0.13)

    let ink = Color.white
    let faint = Color.white.opacity(0.45)
    let accent = Color(red: 1.0, green: 0.42, blue: 0.10)      // orange needle
    let warm = Color(red: 0.96, green: 0.85, blue: 0.25)       // yellow scale
    let cool = Color(red: 0.16, green: 0.74, blue: 0.52)       // green energy arc
    let glass = Color(red: 0.05, green: 0.05, blue: 0.055)

    func draw(in ctx: inout GraphicsContext) {
        let inner = housing(in: &ctx)
        var ctx = clipped(ctx, to: inner)
        draw(in: &ctx, area: inner)
    }

    /// The cluster's metal housing: brushed grey outside, black glass inside. Returns the
    /// inner area to draw in.
    private func housing(in ctx: inout GraphicsContext) -> CGRect {
        let full = CGRect(origin: .zero, size: size)
        let thickness = size.height * 0.035
        let radius = size.height * 0.16

        let shell = Path(roundedRect: full, cornerRadius: radius)
        ctx.fill(shell, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(white: 0.42), location: 0),
                .init(color: Color(white: 0.20), location: 0.18),
                .init(color: Color(white: 0.10), location: 0.5),
                .init(color: Color(white: 0.24), location: 0.88),
                .init(color: Color(white: 0.46), location: 1)
            ]),
            startPoint: CGPoint(x: size.width / 2, y: 0),
            endPoint: CGPoint(x: size.width / 2, y: size.height)))

        // Thin bright edge on top of the metal.
        ctx.stroke(Path(roundedRect: full.insetBy(dx: thickness * 0.18, dy: thickness * 0.18),
                        cornerRadius: radius * 0.94),
                   with: .color(.white.opacity(0.22)), lineWidth: max(1, thickness * 0.1))

        let inner = full.insetBy(dx: thickness, dy: thickness)
        let glassShape = Path(roundedRect: inner, cornerRadius: radius - thickness * 0.6)
        ctx.fill(glassShape, with: .color(.black))
        // Dark shadow at the glass edge, so it sits inside the housing.
        ctx.stroke(glassShape, with: .color(.black.opacity(0.9)),
                   lineWidth: max(1, thickness * 0.35))
        return inner
    }

    private func clipped(_ ctx: GraphicsContext, to rect: CGRect) -> GraphicsContext {
        var copy = ctx
        copy.clip(to: Path(roundedRect: rect, cornerRadius: size.height * 0.12))
        return copy
    }

    private func draw(in ctx: inout GraphicsContext, area: CGRect) {
        let h = area.height
        // Fit three dials side by side: scale to the width, frames included.
        let bigR = min(h * 0.38, area.width * 0.155)
        let smallR = bigR * 0.78
        let centreY = area.minY + h * 0.50

        let mid = CGPoint(x: area.midX, y: centreY)
        let left = CGPoint(x: area.minX + area.width * 0.175, y: centreY + bigR * 0.06)
        let right = CGPoint(x: area.minX + area.width * 0.825, y: centreY + bigR * 0.06)

        drawTacho(in: &ctx, centre: left, radius: smallR)
        drawSpeed(in: &ctx, centre: mid, radius: bigR)
        drawGForce(in: &ctx, centre: right, radius: smallR)
        for (c, rr) in [(left, smallR), (mid, bigR), (right, smallR)] {
            glassSheen(&ctx, centre: c, radius: rr)
        }
        drawPanelGlass(in: &ctx, area: area)
        drawTopRow(in: &ctx, area: area)
        drawBadges(in: &ctx, centre: mid, radius: bigR)
    }

    // MARK: Dial body

    /// Dial body: a machined metal ring, a recessed face inside and a glass reflection on
    /// top. Light comes from the top left.
    private func bezel(_ ctx: inout GraphicsContext, centre: CGPoint, radius r: CGFloat) {
        // The body's shadow on the panel.
        var shadowed = ctx
        shadowed.addFilter(.shadow(color: .black.opacity(0.75), radius: r * 0.14,
                                   x: 0, y: r * 0.05))
        shadowed.fill(circle(centre, r * 1.13), with: .color(Color(white: 0.13)))

        // Lathe-turned metal ring: an angular gradient leaves two bright spots.
        let metal = Gradient(stops: [
            .init(color: Color(white: 0.52), location: 0.00),
            .init(color: Color(white: 0.16), location: 0.16),
            .init(color: Color(white: 0.34), location: 0.34),
            .init(color: Color(white: 0.10), location: 0.52),
            .init(color: Color(white: 0.46), location: 0.70),
            .init(color: Color(white: 0.14), location: 0.86),
            .init(color: Color(white: 0.52), location: 1.00)
        ])
        ctx.fill(circle(centre, r * 1.13),
                 with: .conicGradient(metal, center: centre, angle: .degrees(210)))
        // Inner chamfer of the ring: lit outside, dark inside.
        ctx.stroke(circle(centre, r * 1.04), with: .linearGradient(
            Gradient(colors: [Color(white: 0.58), Color(white: 0.08)]),
            startPoint: CGPoint(x: centre.x - r, y: centre.y - r),
            endPoint: CGPoint(x: centre.x + r, y: centre.y + r)),
                   lineWidth: r * 0.035)

        // Dial face: slightly lighter in the middle, darker at the edge.
        ctx.fill(circle(centre, r * 1.02), with: .radialGradient(
            Gradient(colors: [Color(white: 0.085), Color(white: 0.028)]),
            center: CGPoint(x: centre.x - r * 0.25, y: centre.y - r * 0.3),
            startRadius: 0, endRadius: r * 1.3))

        // Inner shadow at the face edge, so the dial sits recessed.
        ctx.stroke(circle(centre, r * 0.995), with: .color(.black.opacity(0.55)),
                   lineWidth: r * 0.06)
    }

    /// The convex glass over the dial, in three layers: a tilted oval highlight at the top
    /// left, a sharp light at the glass edge and a faint reflection at the bottom right.
    private func glassSheen(_ ctx: inout GraphicsContext, centre: CGPoint, radius r: CGFloat) {
        var clipped = ctx
        clipped.clip(to: circle(centre, r * 1.02))

        // Tilted oval: the main highlight from the glass dome.
        let ovalRect = CGRect(x: centre.x - r * 0.98, y: centre.y - r * 1.02,
                              width: r * 1.62, height: r * 0.92)
        let tilt = CGAffineTransform(translationX: centre.x, y: centre.y)
            .rotated(by: -0.36)
            .translatedBy(x: -centre.x, y: -centre.y)
        let oval = Path(ellipseIn: ovalRect).applying(tilt)
        clipped.fill(oval, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color.white.opacity(0.20), location: 0.0),
                .init(color: Color.white.opacity(0.09), location: 0.45),
                .init(color: Color.white.opacity(0.0), location: 1.0)
            ]),
            startPoint: CGPoint(x: centre.x - r * 0.7, y: centre.y - r * 0.95),
            endPoint: CGPoint(x: centre.x + r * 0.35, y: centre.y + r * 0.1)))

        // Thin sharp light along the glass's top left edge.
        var edge = Path()
        edge.addArc(center: centre, radius: r * 0.985, startAngle: .degrees(186),
                    endAngle: .degrees(292), clockwise: false)
        clipped.stroke(edge, with: .linearGradient(
            Gradient(colors: [Color.white.opacity(0.0), Color.white.opacity(0.45),
                              Color.white.opacity(0.0)]),
            startPoint: CGPoint(x: centre.x - r, y: centre.y),
            endPoint: CGPoint(x: centre.x + r * 0.3, y: centre.y - r)),
                       lineWidth: r * 0.022)

        // Faint reflection off the dial face at the bottom right.
        let bounceRect = CGRect(x: centre.x + r * 0.05, y: centre.y + r * 0.42,
                                width: r * 0.86, height: r * 0.34)
        let bounce = Path(ellipseIn: bounceRect).applying(
            CGAffineTransform(translationX: centre.x, y: centre.y)
                .rotated(by: -0.30)
                .translatedBy(x: -centre.x, y: -centre.y))
        clipped.fill(bounce, with: .linearGradient(
            Gradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.0)]),
            startPoint: CGPoint(x: centre.x + r * 0.2, y: centre.y + r * 0.45),
            endPoint: CGPoint(x: centre.x + r * 0.8, y: centre.y + r * 0.85)))
    }

    private func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    /// Dial scale. Angles run clockwise, with 0 degrees at three o'clock.
    private func scale(_ ctx: inout GraphicsContext, centre: CGPoint, radius r: CGFloat,
                       from start: Double, sweep: Double, divisions: Int,
                       labelEvery: Int, values: (Int) -> String, colour: Color,
                       accentUntil: Int? = nil, accentColour: Color = .white) {
        for i in 0...divisions {
            let a = (start + sweep * Double(i) / Double(divisions)) * .pi / 180
            let major = i % labelEvery == 0
            let tint = accentUntil.map { i <= $0 ? colour : accentColour } ?? colour
            let r0 = r * (major ? 0.80 : 0.87)
            var tick = Path()
            tick.move(to: CGPoint(x: centre.x + r0 * CGFloat(cos(a)),
                                  y: centre.y + r0 * CGFloat(sin(a))))
            tick.addLine(to: CGPoint(x: centre.x + r * 0.95 * CGFloat(cos(a)),
                                     y: centre.y + r * 0.95 * CGFloat(sin(a))))
            ctx.stroke(tick, with: .color(tint.opacity(major ? 1 : 0.65)),
                       lineWidth: r * (major ? 0.022 : 0.011))
            if major {
                let lr = r * 0.70
                text(&ctx, values(i), size: r * 0.115, colour: tint,
                     at: CGPoint(x: centre.x + lr * CGFloat(cos(a)),
                                 y: centre.y + lr * CGFloat(sin(a)) + r * 0.04))
            }
        }
    }

    /// Needle: tapers from the hub to the tip, with a short counterweight behind it and a
    /// shadow on the dial face below.
    private func needle(_ ctx: inout GraphicsContext, centre: CGPoint, radius r: CGFloat,
                        angle degrees: Double) {
        let a = degrees * .pi / 180
        let dx = CGFloat(cos(a)), dy = CGFloat(sin(a))
        func point(_ along: CGFloat, _ across: CGFloat) -> CGPoint {
            CGPoint(x: centre.x + dx * along - dy * across,
                    y: centre.y + dy * along + dx * across)
        }
        var body = Path()
        body.move(to: point(r * 0.97, 0))
        body.addLine(to: point(r * 0.12, r * 0.026))
        body.addLine(to: point(-r * 0.17, r * 0.019))
        body.addLine(to: point(-r * 0.21, 0))
        body.addLine(to: point(-r * 0.17, -r * 0.019))
        body.addLine(to: point(r * 0.12, -r * 0.026))
        body.closeSubpath()

        var shadowed = ctx
        shadowed.addFilter(.shadow(color: .black.opacity(0.65), radius: r * 0.045,
                                   x: r * 0.015, y: r * 0.03))
        // At the shift point the needle turns from orange to red and glows.
        let tint = dash.shiftFlash
            ? accent.mix(with: shiftRed, by: 0.45 + 0.55 * pulse) : accent
        if dash.shiftFlash {
            var glow = ctx
            glow.addFilter(.blur(radius: r * 0.05))
            glow.opacity = 0.5 + 0.5 * pulse
            glow.fill(body, with: .color(shiftRed))
        }
        shadowed.fill(body, with: .linearGradient(
            Gradient(colors: [tint, tint.opacity(0.82)]),
            startPoint: CGPoint(x: centre.x, y: centre.y - r),
            endPoint: CGPoint(x: centre.x, y: centre.y + r)))

        // Krom gobek.
        ctx.fill(circle(centre, r * 0.085), with: .radialGradient(
            Gradient(colors: [Color(white: 0.75), Color(white: 0.22)]),
            center: CGPoint(x: centre.x - r * 0.03, y: centre.y - r * 0.03),
            startRadius: 0, endRadius: r * 0.1))
        ctx.stroke(circle(centre, r * 0.085), with: .color(.black.opacity(0.6)),
                   lineWidth: max(1, r * 0.008))
    }

    // MARK: Left dial - RPM

    private func drawTacho(in ctx: inout GraphicsContext, centre: CGPoint, radius r: CGFloat) {
        bezel(&ctx, centre: centre, radius: r)
        let maxK = max(dash.maxRPM / 1000, 1)
        let start = 145.0, sweep = 250.0
        let every = max(maxK / 5, 1)
        scale(&ctx, centre: centre, radius: r, from: start, sweep: sweep,
              divisions: maxK, labelEvery: every,
              values: { "\($0)" }, colour: warm)

        let fraction = min(max(Double(dash.rpm) / Double(max(dash.maxRPM, 1)), 0), 1)

        // Shift warning: a red arc pulsing over the last part of the scale.
        if dash.shiftFlash {
            var band = Path()
            band.addArc(center: centre, radius: r * 0.88,
                        startAngle: .degrees(start + sweep * 0.82),
                        endAngle: .degrees(start + sweep), clockwise: false)
            var glow = ctx
            glow.addFilter(.blur(radius: r * 0.06))
            glow.stroke(band, with: .color(shiftRed.opacity(0.35 + 0.65 * pulse)),
                        style: StrokeStyle(lineWidth: r * 0.12, lineCap: .round))
            ctx.stroke(band, with: .color(shiftRed.opacity(0.5 + 0.5 * pulse)),
                       style: StrokeStyle(lineWidth: r * 0.06, lineCap: .round))
        }

        needle(&ctx, centre: centre, radius: r, angle: start + sweep * fraction)
        gearWell(&ctx, centre: centre, radius: r)

        text(&ctx, dash.gearLabel, size: r * 0.52, colour: ink, weight: .bold,
             at: CGPoint(x: centre.x, y: centre.y + r * 0.16))
        text(&ctx, "x1000 RPM", size: r * 0.095, colour: faint,
             at: CGPoint(x: centre.x, y: centre.y + r * 0.37))
        // Lap counter below the dial, where the reference had the odometer.
        counter(&ctx, "\(dash.currentLapNum)", label: "LAP",
                centre: CGPoint(x: centre.x, y: centre.y + r * 1.24), radius: r)
    }

    /// The well that holds the gear. Normally a black recess; it glows red and spills light
    /// only at the shift point.
    private func gearWell(_ ctx: inout GraphicsContext, centre: CGPoint, radius r: CGFloat) {
        let well = circle(centre, r * 0.44)
        let heat = dash.shiftFlash ? pulse : 0

        if heat > 0 {
            var glow = ctx
            glow.addFilter(.blur(radius: r * 0.12))
            glow.fill(circle(centre, r * 0.46), with: .color(shiftRed.opacity(heat * 0.8)))
        }

        ctx.fill(well, with: .radialGradient(
            Gradient(colors: [shiftRed.opacity(heat * 0.85),
                              Color.black.opacity(0.96)]),
            center: centre, startRadius: 0, endRadius: r * 0.46))
        ctx.stroke(well, with: .color(heat > 0 ? shiftRed.opacity(0.35 + heat * 0.65)
                                               : Color.white.opacity(0.06)),
                   lineWidth: r * 0.018)
    }

    private func counter(_ ctx: inout GraphicsContext, _ value: String, label: String,
                         centre: CGPoint, radius r: CGFloat) {
        let w = r * 0.62, h = r * 0.20
        let box = Path(roundedRect: CGRect(x: centre.x - w / 2, y: centre.y - h / 2,
                                           width: w, height: h), cornerRadius: h * 0.22)
        ctx.stroke(box, with: .color(faint.opacity(0.5)), lineWidth: max(1, r * 0.012))
        text(&ctx, value, size: h * 0.72, colour: ink,
             at: CGPoint(x: centre.x, y: centre.y + h * 0.26))
        text(&ctx, label, size: r * 0.10, colour: faint,
             at: CGPoint(x: centre.x, y: centre.y + h * 0.95))
    }

    // MARK: Centre dial - speed

    private func drawSpeed(in ctx: inout GraphicsContext, centre: CGPoint, radius r: CGFloat) {
        bezel(&ctx, centre: centre, radius: r)
        let start = 145.0, sweep = 250.0
        let top = 360, step = 20
        let divisions = top / step
        // First half of the scale yellow, second half white, as in the reference.
        scale(&ctx, centre: centre, radius: r, from: start, sweep: sweep,
              divisions: divisions, labelEvery: 3,
              values: { "\($0 * step)" }, colour: warm,
              accentUntil: divisions / 2, accentColour: ink)

        let fraction = min(Double(dash.speedKPH) / Double(top), 1)
        needle(&ctx, centre: centre, radius: r, angle: start + sweep * fraction)
        ctx.fill(circle(centre, r * 0.50), with: .color(.black))
        ctx.stroke(circle(centre, r * 0.50), with: .color(.white.opacity(0.10)),
                   lineWidth: max(1, r * 0.01))

        text(&ctx, "\(dash.speedKPH)", size: r * 0.36, colour: ink, weight: .medium,
             at: CGPoint(x: centre.x, y: centre.y + r * 0.06))
        text(&ctx, "km/h", size: r * 0.10, colour: faint,
             at: CGPoint(x: centre.x, y: centre.y + r * 0.24))

        // ERS arc at the bottom, where the reference had the fuel gauge.
        let arcR = r * 0.80
        var track = Path()
        track.addArc(center: centre, radius: arcR, startAngle: .degrees(42),
                     endAngle: .degrees(138), clockwise: false)
        ctx.stroke(track, with: .color(.white.opacity(0.12)),
                   style: StrokeStyle(lineWidth: r * 0.055, lineCap: .butt))
        var fill = Path()
        let sweepDeg = 96.0 * dash.ersFraction
        fill.addArc(center: centre, radius: arcR, startAngle: .degrees(138 - sweepDeg),
                    endAngle: .degrees(138), clockwise: false)
        ctx.stroke(fill, with: .color(cool),
                   style: StrokeStyle(lineWidth: r * 0.055, lineCap: .butt))
        text(&ctx, String(format: "%.1f", dash.fuelRemainingLaps) + " LAPS",
             size: r * 0.10, colour: cool,
             at: CGPoint(x: centre.x, y: centre.y + r * 0.46))
    }

    // MARK: Right dial - G force

    private func drawGForce(in ctx: inout GraphicsContext, centre: CGPoint, radius r: CGFloat) {
        bezel(&ctx, centre: centre, radius: r)
        let span = r * 0.62          // length of 1 g
        var grid = Path()
        grid.move(to: CGPoint(x: centre.x - span, y: centre.y))
        grid.addLine(to: CGPoint(x: centre.x + span, y: centre.y))
        grid.move(to: CGPoint(x: centre.x, y: centre.y - span))
        grid.addLine(to: CGPoint(x: centre.x, y: centre.y + span))
        ctx.stroke(grid, with: .color(warm.opacity(0.55)), lineWidth: max(1, r * 0.012))

        // Half and full g lines.
        var marks = Path()
        for g in [0.5, 1.0] {
            let d = span * CGFloat(g)
            let len = r * (g == 1 ? 0.13 : 0.09)
            for sx in [-1.0, 1.0] as [CGFloat] {
                marks.move(to: CGPoint(x: centre.x + sx * d, y: centre.y - len))
                marks.addLine(to: CGPoint(x: centre.x + sx * d, y: centre.y + len))
                marks.move(to: CGPoint(x: centre.x - len, y: centre.y + sx * d))
                marks.addLine(to: CGPoint(x: centre.x + len, y: centre.y + sx * d))
            }
        }
        ctx.stroke(marks, with: .color(warm.opacity(0.8)), lineWidth: max(1, r * 0.014))

        // Axis values.
        for g in [0.5, 1.0] {
            let d = span * CGFloat(g)
            let name = g == 1.0 ? "1" : "05"
            text(&ctx, name, size: r * 0.085, colour: warm.opacity(0.9),
                 at: CGPoint(x: centre.x + d, y: centre.y - r * 0.04))
            text(&ctx, name, size: r * 0.085, colour: warm.opacity(0.9),
                 at: CGPoint(x: centre.x - d, y: centre.y - r * 0.04))
            text(&ctx, name, size: r * 0.085, colour: warm.opacity(0.9),
                 at: CGPoint(x: centre.x + r * 0.09, y: centre.y - d + r * 0.03))
            text(&ctx, name, size: r * 0.085, colour: warm.opacity(0.9),
                 at: CGPoint(x: centre.x + r * 0.09, y: centre.y + d + r * 0.03))
        }

        text(&ctx, "G", size: r * 0.13, colour: ink,
             at: CGPoint(x: centre.x - span * 0.95, y: centre.y - span * 0.62))
        text(&ctx, "FORCE", size: r * 0.11, colour: faint,
             at: CGPoint(x: centre.x - span * 0.72, y: centre.y - span * 0.42))

        // Current point: lateral positive to the right, longitudinal positive forward.
        let x = centre.x + span * CGFloat(min(max(dash.gLateral, -1.6), 1.6))
        let y = centre.y - span * CGFloat(min(max(dash.gLongitudinal, -1.6), 1.6))
        ctx.fill(circle(CGPoint(x: x, y: y), r * 0.07), with: .color(accent))
        ctx.stroke(circle(CGPoint(x: x, y: y), r * 0.11), with: .color(accent.opacity(0.5)),
                   lineWidth: max(1, r * 0.012))
    }

    // MARK: Top row and badges

    /// A slanted reflection across the panel glass, darkening towards the edges.
    private func drawPanelGlass(in ctx: inout GraphicsContext, area: CGRect) {
        var band = Path()
        let w = area.width, h = area.height
        band.move(to: CGPoint(x: area.minX - w * 0.1, y: area.minY + h * 0.30))
        band.addLine(to: CGPoint(x: area.minX + w * 0.42, y: area.minY - h * 0.1))
        band.addLine(to: CGPoint(x: area.minX + w * 0.60, y: area.minY - h * 0.1))
        band.addLine(to: CGPoint(x: area.minX - w * 0.1, y: area.minY + h * 0.72))
        band.closeSubpath()
        ctx.fill(band, with: .linearGradient(
            Gradient(colors: [Color.white.opacity(0.035), Color.white.opacity(0.0)]),
            startPoint: CGPoint(x: area.minX, y: area.minY),
            endPoint: CGPoint(x: area.midX, y: area.maxY)))

        ctx.fill(Path(area), with: .radialGradient(
            Gradient(colors: [Color.black.opacity(0), Color.black.opacity(0.45)]),
            center: CGPoint(x: area.midX, y: area.midY),
            startRadius: area.height * 0.35, endRadius: area.width * 0.62))
    }

    private func drawTopRow(in ctx: inout GraphicsContext, area: CGRect) {
        let y = area.minY + area.height * 0.12
        text(&ctx, "\(dash.engineTemp)°C", size: area.height * 0.048, colour: faint,
             at: CGPoint(x: area.minX + area.width * 0.37, y: y))
        text(&ctx, dash.currentLapTimeText, size: area.height * 0.048, colour: faint,
             at: CGPoint(x: area.minX + area.width * 0.63, y: y))
    }

    private func drawBadges(in ctx: inout GraphicsContext, centre: CGPoint, radius r: CGFloat) {
        let y = centre.y + r * 1.28
        badge(&ctx, dash.ersModeText, colour: warm,
              centre: CGPoint(x: centre.x - r * 0.52, y: y), radius: r)
        let boost = dash.boostActive ? dash.boostLabel
                  : (dash.boostAvailable ? dash.boostLabel : "P\(dash.carPosition)")
        badge(&ctx, boost, colour: dash.boostActive ? accent : cool,
              centre: CGPoint(x: centre.x + r * 0.52, y: y), radius: r)
    }

    private func badge(_ ctx: inout GraphicsContext, _ title: String, colour: Color,
                       centre: CGPoint, radius r: CGFloat) {
        let w = r * 0.76, h = r * 0.19
        let box = Path(roundedRect: CGRect(x: centre.x - w / 2, y: centre.y - h / 2,
                                           width: w, height: h), cornerRadius: h * 0.2)
        ctx.stroke(box, with: .color(colour), lineWidth: max(1, r * 0.012))
        text(&ctx, title, size: h * 0.62, colour: colour,
             at: CGPoint(x: centre.x, y: centre.y + h * 0.22))
    }

    // MARK: Text

    private func text(_ ctx: inout GraphicsContext, _ string: String, size fontSize: CGFloat,
                      colour: Color, weight: Font.Weight = .semibold,
                      at point: CGPoint) {
        let resolved = ctx.resolve(
            Text(verbatim: string)
                .font(.system(size: fontSize, weight: weight))
                .foregroundColor(colour))
        ctx.draw(resolved, at: point, anchor: .bottom)
    }
}

extension Color {
    /// Mixes two colours by a fraction; used for the orange to red warning pulse.
    func mix(with other: Color, by amount: Double) -> Color {
        let t = min(max(amount, 0), 1)
        let a = UIColor(self), b = UIColor(other)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(red: Double(ar + (br - ar) * t),
                     green: Double(ag + (bg - ag) * t),
                     blue: Double(ab + (bb - ab) * t))
    }
}
