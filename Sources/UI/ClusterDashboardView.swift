import SwiftUI

/// Modern bir spor otomobilin dijital gosterge paneli: siyah cam uzerinde uc
/// yuvarlak kadran. Solda devir, ortada hiz ve enerji, sagda G kuvveti.
struct ClusterDashboardView: View {
    let dash: DashboardModel
    let unit: CGFloat

    var body: some View {
        GeometryReader { geo in
            // Vites uyarisi disinda zamanlayici durur; pano zaten telemetriyle
            // yeniden cizilir.
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
    /// Vites uyarisi animasyonunun zaman tabani.
    var time: TimeInterval = 0

    /// 0 ile 1 arasinda gidip gelen uyari nabzi.
    private var pulse: Double {
        guard dash.shiftFlash else { return 0 }
        return 0.5 + 0.5 * sin(time * 18)
    }
    let shiftRed = Color(red: 1.0, green: 0.16, blue: 0.13)

    let ink = Color.white
    let faint = Color.white.opacity(0.45)
    let accent = Color(red: 1.0, green: 0.42, blue: 0.10)      // turuncu ibre
    let warm = Color(red: 0.96, green: 0.85, blue: 0.25)       // sari olcek
    let cool = Color(red: 0.16, green: 0.74, blue: 0.52)       // yesil yakit yayi
    let glass = Color(red: 0.05, green: 0.05, blue: 0.055)

    func draw(in ctx: inout GraphicsContext) {
        let inner = housing(in: &ctx)
        var ctx = clipped(ctx, to: inner)
        draw(in: &ctx, area: inner)
    }

    /// Panelin metal govdesi: disi firincalanmis gri, ici siyah cam.
    /// Geriye cizimin yapilacagi ic alani dondurur.
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

        // Metalin ustundeki ince parlak kenar.
        ctx.stroke(Path(roundedRect: full.insetBy(dx: thickness * 0.18, dy: thickness * 0.18),
                        cornerRadius: radius * 0.94),
                   with: .color(.white.opacity(0.22)), lineWidth: max(1, thickness * 0.1))

        let inner = full.insetBy(dx: thickness, dy: thickness)
        let glassShape = Path(roundedRect: inner, cornerRadius: radius - thickness * 0.6)
        ctx.fill(glassShape, with: .color(.black))
        // Camin kenarindaki koyu golge, govdeye oturmus gibi dursun.
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
        // Uc kadran yan yana sigsin: cercevelerle birlikte genislige gore olcek.
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

    // MARK: Kadran govdesi

    /// Kadran govdesi: islenmis metal halka, icine cukur oturmus yuz ve
    /// ustunden gecen cam yansimasi. Isik sol ustten gelir.
    private func bezel(_ ctx: inout GraphicsContext, centre: CGPoint, radius r: CGFloat) {
        // Govdenin panele dusen golgesi.
        var shadowed = ctx
        shadowed.addFilter(.shadow(color: .black.opacity(0.75), radius: r * 0.14,
                                   x: 0, y: r * 0.05))
        shadowed.fill(circle(centre, r * 1.13), with: .color(Color(white: 0.13)))

        // Torna izli metal halka: acili gradyan iki parlak nokta birakir.
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
        // Halkanin ic pahi: disi aydinlik, ici karanlik.
        ctx.stroke(circle(centre, r * 1.04), with: .linearGradient(
            Gradient(colors: [Color(white: 0.58), Color(white: 0.08)]),
            startPoint: CGPoint(x: centre.x - r, y: centre.y - r),
            endPoint: CGPoint(x: centre.x + r, y: centre.y + r)),
                   lineWidth: r * 0.035)

        // Kadran yuzu: ortasi bir tik acik, kenari koyu.
        ctx.fill(circle(centre, r * 1.02), with: .radialGradient(
            Gradient(colors: [Color(white: 0.085), Color(white: 0.028)]),
            center: CGPoint(x: centre.x - r * 0.25, y: centre.y - r * 0.3),
            startRadius: 0, endRadius: r * 1.3))

        // Yuzun kenarindaki ic golge: kadran cukurda dursun.
        ctx.stroke(circle(centre, r * 0.995), with: .color(.black.opacity(0.55)),
                   lineWidth: r * 0.06)
    }

    /// Kadranin uzerindeki disbukey cam. Uc katman: sol ustte egik oval
    /// parlama, cam kenarindaki keskin isik ve alt sagda zayif bir yansima.
    private func glassSheen(_ ctx: inout GraphicsContext, centre: CGPoint, radius r: CGFloat) {
        var clipped = ctx
        clipped.clip(to: circle(centre, r * 1.02))

        // Egik oval: camin kubbesinden gelen ana parlama.
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

        // Camin sol ust kenarindaki ince keskin isik.
        var edge = Path()
        edge.addArc(center: centre, radius: r * 0.985, startAngle: .degrees(186),
                    endAngle: .degrees(292), clockwise: false)
        clipped.stroke(edge, with: .linearGradient(
            Gradient(colors: [Color.white.opacity(0.0), Color.white.opacity(0.45),
                              Color.white.opacity(0.0)]),
            startPoint: CGPoint(x: centre.x - r, y: centre.y),
            endPoint: CGPoint(x: centre.x + r * 0.3, y: centre.y - r)),
                       lineWidth: r * 0.022)

        // Alt sagda, kadran yuzunden donen zayif yansima.
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

    /// Kadran olcegi. Aci, saat yonunde ve 0 derece saat uc yonu.
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

    /// Ibre: gobekten uca dogru incelir, arkasinda kisa bir karsi agirlik
    /// ve altinda kadran yuzune dusen golge vardir.
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
        // Vites zamani geldiginde ibre turuncudan kirmiziya doner ve isir.
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

    // MARK: Sol kadran - devir

    private func drawTacho(in ctx: inout GraphicsContext, centre: CGPoint, radius r: CGFloat) {
        bezel(&ctx, centre: centre, radius: r)
        let maxK = max(dash.maxRPM / 1000, 1)
        let start = 145.0, sweep = 250.0
        let every = max(maxK / 5, 1)
        scale(&ctx, centre: centre, radius: r, from: start, sweep: sweep,
              divisions: maxK, labelEvery: every,
              values: { "\($0)" }, colour: warm)

        let fraction = min(max(Double(dash.rpm) / Double(max(dash.maxRPM, 1)), 0), 1)

        // Vites uyarisi: olcegin son diliminde nabiz gibi atan kirmizi yay.
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
        // Kadranin altinda tur sayaci, referanstaki kilometre gostergesi gibi.
        counter(&ctx, "\(dash.currentLapNum)", label: "LAP",
                centre: CGPoint(x: centre.x, y: centre.y + r * 1.24), radius: r)
    }

    /// Vitesin durdugu yuva. Normalde siyah bir cukur; yalnizca vites zamani
    /// geldiginde kizarip cevresine isik sizdirir.
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

    // MARK: Orta kadran - hiz

    private func drawSpeed(in ctx: inout GraphicsContext, centre: CGPoint, radius r: CGFloat) {
        bezel(&ctx, centre: centre, radius: r)
        let start = 145.0, sweep = 250.0
        let top = 360, step = 20
        let divisions = top / step
        // Olcegin ilk yarisi sari, ikinci yarisi beyaz: referanstaki ayrim.
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

        // Altta ERS yayi: referanstaki yakit gostergesinin yeri.
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

    // MARK: Sag kadran - G kuvveti

    private func drawGForce(in ctx: inout GraphicsContext, centre: CGPoint, radius r: CGFloat) {
        bezel(&ctx, centre: centre, radius: r)
        let span = r * 0.62          // 1 g bu uzunluga karsilik gelir
        var grid = Path()
        grid.move(to: CGPoint(x: centre.x - span, y: centre.y))
        grid.addLine(to: CGPoint(x: centre.x + span, y: centre.y))
        grid.move(to: CGPoint(x: centre.x, y: centre.y - span))
        grid.addLine(to: CGPoint(x: centre.x, y: centre.y + span))
        ctx.stroke(grid, with: .color(warm.opacity(0.55)), lineWidth: max(1, r * 0.012))

        // Yarim ve tam g cizgileri.
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

        // Eksen degerleri.
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

        // Anlik nokta: saga pozitif yanal, ileri pozitif boyuna.
        let x = centre.x + span * CGFloat(min(max(dash.gLateral, -1.6), 1.6))
        let y = centre.y - span * CGFloat(min(max(dash.gLongitudinal, -1.6), 1.6))
        ctx.fill(circle(CGPoint(x: x, y: y), r * 0.07), with: .color(accent))
        ctx.stroke(circle(CGPoint(x: x, y: y), r * 0.11), with: .color(accent.opacity(0.5)),
                   lineWidth: max(1, r * 0.012))
    }

    // MARK: Ust satir ve rozetler

    /// Panelin camindan gecen egik yansima ve kenarlara dogru karartma.
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

    // MARK: Yazi

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
    /// Iki rengi oranla karistirir; uyari nabzinda turuncudan kirmiziya gecis icin.
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
