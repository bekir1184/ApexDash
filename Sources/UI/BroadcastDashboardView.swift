import SwiftUI

/// The blue TV graphics HUD. Geometry is carried over exactly from the approved SVG
/// prototype (a 2170 x 1000 design space, R = 340): a dotted speed dial in the middle, ring
/// segments concentric with it on both sides (the RECHARGE / DEPLOY panels and BRAKE /
/// THROTTLE blocks), the battery below, and the gear, RPM and active aero strip along the
/// bottom.
struct BroadcastDashboardView: View {
    let dash: DashboardModel
    let unit: CGFloat

    var body: some View {
        GeometryReader { geo in
            let layout = BroadcastLayout(size: geo.size)
            Canvas(rendersAsynchronously: false) { context, _ in
                var ctx = context
                BroadcastHUD(dash: dash).draw(in: &ctx, layout: layout)
            }
            .overlay {
                // The shift warning flashes inside the dial's (stretched) ellipse.
                let frame = layout.centre(BroadcastHUD(dash: dash).dialFrame)
                ShiftFlashOverlay(active: dash.shiftFlash, color: Color(hex: 0x63d6dd))
                    .clipShape(Ellipse())
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
        }
    }
}

/// The centre group (dial, panels, blocks, battery) fits its design height to the screen
/// height; the side bands scale separately to fit the remaining width and align to the
/// bottom corners, on the same baseline as the block labels.
struct BroadcastLayout {
    let size: CGSize
    let centreScale: CGFloat
    /// Horizontal scale: the centre group stretches to fill the screen from side to side.
    let centreScaleX: CGFloat
    /// The row along the bottom of the screen: active aero, gear ruler, RPM.
    let strip: CGRect

    /// Vertical extent of the centre group in design space: from the top of the stretched
    /// bezel to the bottom of the BRAKE / THROTTLE labels.
    static let designTop: CGFloat = 20
    static let designBottom: CGFloat = 906
    static let designCentreX: CGFloat = 1085

    init(size: CGSize) {
        self.size = size
        let R: CGFloat = 340
        let stripH = size.height * 0.16, gap = size.height * 0.02, margin = size.width * 0.012
        strip = CGRect(x: margin, y: size.height - stripH, width: size.width - 2 * margin, height: stripH)
        let areaH = size.height - stripH - gap
        centreScale = min(areaH / (Self.designBottom - Self.designTop), size.width / (R * 4.1))
        // The blocks' outer edge is at 1.96R; the width spreads accordingly, stretching by
        // at most 20 %.
        centreScaleX = min((size.width - 2 * margin) / (R * 4.0), centreScale * 1.2)
    }

    /// Maps the centre group rectangle from design coordinates to the screen.
    func centre(_ rect: CGRect) -> CGRect {
        let x = size.width / 2 + (rect.minX - Self.designCentreX) * centreScaleX
        let span = (Self.designBottom - Self.designTop) * centreScale
        let areaH = strip.minY - size.height * 0.02
        let y = (areaH - span) / 2 + (rect.minY - Self.designTop) * centreScale
        return CGRect(x: x, y: y, width: rect.width * centreScaleX, height: rect.height * centreScale)
    }

    func applyCentre(to ctx: inout GraphicsContext) {
        let origin = centre(CGRect(x: 0, y: 0, width: 0, height: 0)).origin
        ctx.translateBy(x: origin.x, y: origin.y)
        ctx.scaleBy(x: centreScaleX, y: centreScale)
    }
}

// MARK: - Drawing

/// Everything in design space, drawn in one pass on a GraphicsContext.
struct BroadcastHUD {
    let dash: DashboardModel

    // Constants from the prototype
    let R: CGFloat = 340
    let CX: CGFloat = 1085
    let CY: CGFloat = 480
    var corner: CGFloat { R * 0.13 }
    /// The dial, panels and blocks stretch upwards from the base by this factor.
    let stretch: CGFloat = 1.12
    var stretchBase: CGFloat { CY + R * 1.09 }

    // Renkler (referanstan olculen)
    let blockFill = Color(hex: 0x0a1a27)
    let blockEdge = Color(hex: 0x3b83a8)
    let slatOff = Color(hex: 0x1a3a4e)
    let panelTop = Color(hex: 0x27578c)
    let panelBottom = Color(hex: 0x1e4a7c)
    let panelEdge = Color(hex: 0x6db8e6)
    let panelInk = Color(hex: 0x8fc6ea)
    let ring = Color(hex: 0x63d6dd)
    let ringInner = Color(hex: 0x2e7f96)
    let green = Color(hex: 0x4dff7a)
    let teal = Color(hex: 0x3fd9c9)
    let cyanInk = Color(hex: 0x8fe4f0)

    /// Bounding rectangle of the stretched dial (design coordinates).
    var dialFrame: CGRect {
        let r = R * 1.03
        let top = stretchBase - (stretchBase - (CY - r)) * stretch
        let bottom = stretchBase - (stretchBase - (CY + r)) * stretch
        return CGRect(x: CX - r, y: top, width: 2 * r, height: bottom - top)
    }

    func draw(in ctx: inout GraphicsContext, layout: BroadcastLayout) {
        drawBottomStrip(in: &ctx, rect: layout.strip)

        layout.applyCentre(to: &ctx)
        var stretched = ctx
        stretched.translateBy(x: 0, y: stretchBase)
        stretched.scaleBy(x: 1, y: stretch)
        stretched.translateBy(x: 0, y: -stretchBase)

        drawSlatBlock(in: &stretched, side: .left, lit: litCount(Double(dash.brake)),
                      colour: Color(hex: 0xff3b3b), label: "BRAKE")
        drawSlatBlock(in: &stretched, side: .right, lit: litCount(Double(dash.throttle)),
                      colour: Color(hex: 0x3ff06a), label: "THROTTLE")
        drawLabelPanel(in: &stretched, side: .left, text: "RECHARGE",
                       level: dash.harvestFraction, active: dash.ersTrend > 0)
        drawLabelPanel(in: &stretched, side: .right, text: "DEPLOY",
                       level: deployLevel, active: deployActive)
        drawDial(in: &stretched)

        drawBattery(in: &ctx)
    }

    /// Energy deployed this lap, against the battery capacity (4 MJ): full at the start of
    /// the lap, falling at the same rate as the battery while overtake is on. Scaled to the
    /// lap limit (5-9 MJ), short bursts barely moved it.
    private var deployLevel: Double {
        1 - min(max(Double(dash.ersDeployedThisLap) / 4_000_000, 0), 1)
    }

    private var deployActive: Bool { dash.ersTrend < 0 || dash.boostActive }

    private func litCount(_ fraction: Double) -> Int {
        Int((min(max(fraction, 0), 1) * 10).rounded())
    }

    // MARK: Ring segment geometry

    enum Side { case left, right }

    /// P(r, a) from the prototype: the x axis is mirrored on the left side.
    private func point(_ side: Side, _ r: CGFloat, _ a: CGFloat) -> CGPoint {
        CGPoint(x: CX + (side == .left ? -1 : 1) * r * cos(a), y: CY + r * sin(a))
    }

    private func angle(_ side: Side, _ a: CGFloat) -> Angle {
        .radians(side == .left ? Double(.pi - a) : Double(a))
    }

    /// A ring segment: inner arc from a0 to a1, outer arc from a1 to a0.
    private func ringSlice(_ side: Side, rIn: CGFloat, rOut: CGFloat,
                           a0: CGFloat, a1: CGFloat) -> Path {
        var p = Path()
        let c = CGPoint(x: CX, y: CY)
        let s0 = angle(side, a0), s1 = angle(side, a1)
        p.move(to: point(side, rIn, a0))
        p.addArc(center: c, radius: rIn, startAngle: s0, endAngle: s1,
                 clockwise: s1.radians < s0.radians)
        p.addLine(to: point(side, rOut, a1))
        p.addArc(center: c, radius: rOut, startAngle: s1, endAngle: s0,
                 clockwise: s0.radians < s1.radians)
        p.closeSubpath()
        return p
    }

    /// A segment with rounded corners: the shape is inset by `c` and stroked in the same
    /// colour with a round-joined 2c line, which brings it back to full size.
    private struct RoundedSegment {
        let path: Path
        let strokeWidth: CGFloat
    }

    private func roundedSegment(_ side: Side, rIn: CGFloat, rOut: CGFloat,
                                aTop: CGFloat, aBottom: CGFloat, c: CGFloat) -> RoundedSegment {
        let rMid = (rIn + rOut) / 2, da = c / rMid
        return RoundedSegment(path: ringSlice(side, rIn: rIn + c, rOut: rOut - c,
                                              a0: aTop + da, a1: aBottom - da),
                              strokeWidth: 2 * c)
    }

    private func fillRounded(_ ctx: inout GraphicsContext, _ seg: RoundedSegment,
                             _ shading: GraphicsContext.Shading, widthDelta: CGFloat = 0) {
        ctx.fill(seg.path, with: shading)
        ctx.stroke(seg.path, with: shading,
                   style: StrokeStyle(lineWidth: seg.strokeWidth + widthDelta, lineJoin: .round))
    }

    private func strokeRounded(_ ctx: inout GraphicsContext, _ seg: RoundedSegment,
                               _ colour: Color, extra: CGFloat) {
        ctx.stroke(seg.path, with: .color(colour),
                   style: StrokeStyle(lineWidth: seg.strokeWidth + extra, lineJoin: .round))
    }

    // MARK: BRAKE / THROTTLE blocks

    private func drawSlatBlock(in ctx: inout GraphicsContext, side: Side, lit: Int,
                               colour: Color, label: String) {
        let rIn = R * 1.58, rOut = R * 1.96, rMid = (rIn + rOut) / 2
        let aTop = -asin(0.40 * R / rMid), aBottom = asin(0.91 * R / rMid)
        let seg = roundedSegment(side, rIn: rIn, rOut: rOut, aTop: aTop, aBottom: aBottom, c: corner)

        fillRounded(&ctx, seg, .color(blockFill))
        strokeRounded(&ctx, seg, blockEdge.opacity(0.8), extra: 2.5)
        fillRounded(&ctx, seg, .color(blockFill), widthDelta: -2.5)

        // Segments are masked by a copy of the block inset by padR with rounded corners.
        let padR = R * 0.05, padA = padR / rMid
        let inner = roundedSegment(side, rIn: rIn + padR, rOut: rOut - padR,
                                   aTop: aTop + padA, aBottom: aBottom - padA, c: corner - padR)
        var masked = ctx
        masked.clipToLayer { layer in
            layer.fill(inner.path, with: .color(.white))
            layer.stroke(inner.path, with: .color(.white),
                         style: StrokeStyle(lineWidth: inner.strokeWidth, lineJoin: .round))
        }
        let n = 10, gap = (aBottom - aTop) * 0.028
        let r0 = rIn + padR * 0.4, r1 = rOut - padR * 0.4
        let step = (aBottom - aTop) / CGFloat(n)
        for i in 0..<n {
            let a0 = aTop + CGFloat(i) * step + gap / 2
            let a1 = aTop + CGFloat(i + 1) * step - gap / 2
            let slice = ringSlice(side, rIn: r0, rOut: r1, a0: a0, a1: a1)
            let on = i >= n - lit
            let c: Color = on ? colour : slatOff
            masked.fill(slice, with: .color(c))
            masked.stroke(slice, with: .color(c),
                          style: StrokeStyle(lineWidth: R * 0.012, lineJoin: .round))
        }

        let bottom = point(side, rOut, aBottom).y
        drawText(&ctx, label, size: 47, weight: .heavy, italic: true, colour: .white,
                 at: CGPoint(x: point(side, rMid, aBottom).x, y: bottom + R * 0.20))
    }

    // MARK: RECHARGE / DEPLOY panels

    private func drawLabelPanel(in ctx: inout GraphicsContext, side: Side, text: String,
                                level: Double, active: Bool) {
        let rIn = R * 1.125, rOut = R * 1.52, rMid = (rIn + rOut) / 2
        let aTop = -asin(0.56 * R / rMid), aBottom = asin(0.88 * R / rMid)
        let seg = roundedSegment(side, rIn: rIn, rOut: rOut, aTop: aTop, aBottom: aBottom, c: corner)

        let top = point(side, rMid, aTop).y, bottom = point(side, rMid, aBottom).y
        // A dim base, filled from the bottom up to the level. While active the panel turns
        // bright blue, light spills around it and the letters turn white.
        if active {
            var glow = ctx
            glow.addFilter(.blur(radius: R * 0.05))
            strokeRounded(&glow, seg, Color(hex: 0x6fd6ff).opacity(0.9), extra: R * 0.06)
        }
        strokeRounded(&ctx, seg, active ? .white : panelEdge, extra: 3)
        fillRounded(&ctx, seg, .color(active ? Color(hex: 0x1d4f86) : Color(hex: 0x123153)), widthDelta: -2.5)
        let clamped = CGFloat(min(max(level, 0), 1))
        if clamped > 0 {
            let colours = active ? [Color(hex: 0x7fe0ff), Color(hex: 0x2f96e6)] : [panelTop, panelBottom]
            let gradient = GraphicsContext.Shading.linearGradient(
                Gradient(colors: colours),
                startPoint: CGPoint(x: CX, y: top), endPoint: CGPoint(x: CX, y: bottom))
            var filled = ctx
            let outerTop = point(side, rOut, aTop).y - corner
            let outerBottom = point(side, rOut, aBottom).y + corner
            let fillTop = outerBottom - (outerBottom - outerTop) * clamped
            filled.clip(to: Path(CGRect(x: 0, y: fillTop, width: 2170, height: outerBottom - fillTop)))
            fillRounded(&filled, seg, gradient, widthDelta: -2.5)
        }

        // Letters along the middle radius, upright, at equal angles
        let letters = Array(text)
        let pad: CGFloat = 0.09
        for (i, ch) in letters.enumerated() {
            let a = aTop + pad + (aBottom - aTop - 2 * pad) * CGFloat(i) / CGFloat(letters.count - 1)
            let p = point(side, rMid, a)
            drawText(&ctx, String(ch), size: 47, weight: .heavy, italic: true,
                     colour: active ? .white : panelInk,
                     at: CGPoint(x: p.x, y: p.y + R * 0.055))
        }
    }

    // MARK: Dial

    private static var dotPattern: Path = {
        var p = Path()
        let step: CGFloat = 9
        var y: CGFloat = -350
        while y < 350 {
            var x: CGFloat = -350
            while x < 350 {
                p.addEllipse(in: CGRect(x: x + 2.5 - 1.8, y: y + 2.5 - 1.8, width: 3.6, height: 3.6))
                x += step
            }
            y += step
        }
        return p
    }()

    private static var hatchPattern: Path = {
        var p = Path()
        var x: CGFloat = 0
        while x < 560 {
            p.addRect(CGRect(x: x, y: 0, width: 5, height: 40))
            x += 14
        }
        return p
    }()

    private func drawDial(in ctx: inout GraphicsContext) {
        let centre = CGPoint(x: CX, y: CY)
        func circle(_ r: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: CX - r, y: CY - r, width: 2 * r, height: 2 * r))
        }

        ctx.fill(circle(R * 1.09), with: .color(Color(hex: 0x07131d)))
        ctx.fill(circle(R), with: .color(Color(hex: 0x0d1c2b)))
        var dots = ctx
        dots.clip(to: circle(R))
        dots.translateBy(x: CX, y: CY)
        dots.fill(Self.dotPattern, with: .color(Color(hex: 0x16405c)))

        // Ring outlines fade as they approach the battery.
        var rings = ctx
        rings.clipToLayer { layer in
            let fade = Gradient(stops: [
                .init(color: .white.opacity(0), location: 0),
                .init(color: .white.opacity(0), location: 0.55),
                .init(color: .white, location: 1)
            ])
            layer.fill(Path(CGRect(x: 0, y: 0, width: 2170, height: 1000)),
                       with: .radialGradient(fade, center: CGPoint(x: CX, y: CY + R * 0.98),
                                             startRadius: 0, endRadius: R * 0.75))
        }
        rings.stroke(circle(R * 1.03), with: .color(ring), lineWidth: R * 0.02)
        rings.stroke(circle(R * 0.96), with: .color(ringInner), lineWidth: 2)

        // Inside the dial
        drawText(&ctx, dash.speedUnitLabel, size: 59, weight: .bold, italic: false, colour: .white,
                 at: CGPoint(x: CX, y: CY - R * 0.66))
        drawText(&ctx, "\(dash.speedKPH)", size: 197, weight: .heavy, italic: false, colour: .white,
                 at: CGPoint(x: CX, y: CY - R * 0.11))

        var hatch = ctx
        hatch.translateBy(x: CX - R * 0.81, y: CY + R * 0.04)
        hatch.clip(to: Path(CGRect(x: 0, y: 0, width: R * 1.62, height: R * 0.18)))
        hatch.fill(Self.hatchPattern, with: .color(Color(hex: 0x2a4258).opacity(0.85)))
        drawText(&ctx, "BOOST", size: 52, weight: .bold, italic: false,
                 colour: Color(hex: 0x9fb6c4), tracking: 3,
                 at: CGPoint(x: CX, y: CY + R * 0.18))

        let box = Path(roundedRect: CGRect(x: CX - R * 0.72, y: CY + R * 0.28,
                                           width: R * 1.44, height: R * 0.22), cornerRadius: 5)
        let available = dash.boostAvailable || dash.boostActive
        ctx.fill(box, with: .color(dash.boostActive ? green : Color(hex: 0x0b2a16)))
        ctx.stroke(box, with: .color(green.opacity(available ? 1 : 0.3)), lineWidth: 5)
        drawText(&ctx, dash.boostLabel, size: 52, weight: .bold, italic: false,
                 colour: dash.boostActive ? .black : green.opacity(available ? 1 : 0.35), tracking: 2,
                 at: CGPoint(x: CX, y: CY + R * 0.43))
        _ = centre
    }

    // MARK: Battery

    private func drawBattery(in ctx: inout GraphicsContext) {
        let bw = R * 0.80, bh = R * 0.24, by = CY + R * 0.86
        let rect = CGRect(x: CX - bw / 2, y: by, width: bw, height: bh)
        let body = Path(roundedRect: rect, cornerRadius: bh * 0.30)
        // As in the game: yellow normally, blue while overtake is engaged.
        let blue = dash.boostActive
        let empty = blue ? Color(hex: 0x21497f) : Color(hex: 0x5a4a12)
        let full = blue ? Color(hex: 0x3980d0) : Color(hex: 0xf0c330)
        let edge = blue ? Color(hex: 0x7bbfe4) : Color(hex: 0xffe27a)
        let nub = blue ? Color(hex: 0x7ee0f0) : Color(hex: 0xffe27a)
        ctx.fill(body, with: .color(empty))
        var level = ctx
        level.clip(to: body)
        level.fill(Path(CGRect(x: rect.minX, y: rect.minY, width: bw * dash.ersFraction, height: bh)),
                   with: .color(full))
        ctx.stroke(body, with: .color(edge), lineWidth: 5)
        ctx.fill(Path(roundedRect: CGRect(x: rect.maxX + 1, y: by + bh * 0.28,
                                          width: bh * 0.18, height: bh * 0.44), cornerRadius: 3),
                 with: .color(nub))

        // Lightning bolt
        let s = bh * 0.9, x = CX, y = by + bh * 0.5 - s / 2
        var bolt = Path()
        bolt.move(to: CGPoint(x: x + s * 0.18, y: y))
        bolt.addLine(to: CGPoint(x: x + s * 0.18 - s * 0.45, y: y + s * 0.55))
        bolt.addLine(to: CGPoint(x: x + s * 0.18 - s * 0.45 + s * 0.3, y: y + s * 0.55))
        bolt.addLine(to: CGPoint(x: x + s * 0.18 - s * 0.45 + s * 0.3 - s * 0.18, y: y + s * 0.55 + s * 0.45))
        bolt.addLine(to: CGPoint(x: x + s * 0.18 - s * 0.45 + s * 0.3 - s * 0.18 + s * 0.5, y: y + s * 0.55 + s * 0.45 - s * 0.6))
        bolt.addLine(to: CGPoint(x: x + s * 0.18 - s * 0.45 + s * 0.3 - s * 0.18 + s * 0.5 - s * 0.3, y: y + s * 0.55 + s * 0.45 - s * 0.6))
        bolt.closeSubpath()
        ctx.fill(bolt, with: .color(blue ? Color(hex: 0xb5e9fa) : Color(hex: 0x2a2205)))
    }

    // MARK: Bottom strip

    /// The row along the bottom of the screen: ACTIVE AERO on the left, the gear ruler in
    /// the middle, the RPM bar on the right. Drawn in screen coordinates; the unit is the
    /// strip height.
    private func drawBottomStrip(in ctx: inout GraphicsContext, rect: CGRect) {
        let h = rect.height, k = h / 100          // 100 units = strip height
        let path = Path(roundedRect: rect, cornerRadius: h * 0.22)
        ctx.fill(path, with: .color(blockFill))
        ctx.stroke(path, with: .color(blockEdge), lineWidth: max(1.5, k * 2))

        let pad = h * 0.35, x0 = rect.minX + pad, x1 = rect.maxX - pad
        let midY = rect.midY

        // Left: ACTIVE AERO and a double line
        let aero = dash.aeroEngaged
        drawText(&ctx, dash.aeroTitle, size: k * 24, weight: .heavy, italic: true,
                 colour: aero ? .white : Color(hex: 0x6f8797), anchor: .leading,
                 at: CGPoint(x: x0, y: midY + k * 8))
        let sx = x0 + k * 170
        var slashes = Path()
        slashes.move(to: CGPoint(x: sx, y: midY + k * 14)); slashes.addLine(to: CGPoint(x: sx + k * 14, y: midY - k * 14))
        slashes.move(to: CGPoint(x: sx + k * 22, y: midY + k * 14)); slashes.addLine(to: CGPoint(x: sx + k * 36, y: midY - k * 14))
        ctx.stroke(slashes, with: .color(aero ? Color(hex: 0x3fe0f0) : Color(hex: 0x3d5566)),
                   style: StrokeStyle(lineWidth: k * 5, lineCap: .round))

        // Middle: gear ruler R, N and 1...8, up to the game's gear count
        let gears = ["R", "N"] + (1...max(min(dash.maxGears, 8), 1)).map(String.init)
        let gx0 = rect.minX + rect.width * 0.31, gx1 = rect.minX + rect.width * 0.62
        for (i, label) in gears.enumerated() {
            let x = gx0 + (gx1 - gx0) * CGFloat(i) / CGFloat(gears.count - 1)
            let on = label == dash.gearLabel
            drawText(&ctx, label, size: on ? k * 46 : k * 30, weight: .heavy, italic: true,
                     colour: on ? .white : Color(hex: 0x4d6a7c), at: CGPoint(x: x, y: midY + k * 12))
        }
        drawText(&ctx, "GEARS", size: k * 18, weight: .heavy, italic: true, colour: Color(hex: 0x9fb6c4),
                 anchor: .leading, at: CGPoint(x: gx1 + k * 30, y: midY + k * 8))

        // Right: RPM bar
        let bx0 = rect.minX + rect.width * 0.72, bx1 = x1
        let by = midY - k * 4
        let track = Path(roundedRect: CGRect(x: bx0, y: by, width: bx1 - bx0, height: k * 10), cornerRadius: k * 5)
        ctx.fill(track, with: .color(slatOff))
        let fraction = min(max(Double(dash.rpm) / Double(max(dash.maxRPM, 1)), 0), 1)
        if fraction > 0 {
            ctx.fill(Path(roundedRect: CGRect(x: bx0, y: by, width: (bx1 - bx0) * fraction, height: k * 10),
                          cornerRadius: k * 5),
                     with: .color(dash.shiftFlash ? .white : teal))
        }
        let tick = Color(hex: 0x9fb6c4)
        drawText(&ctx, "0", size: k * 16, weight: .bold, italic: false, colour: tick,
                 at: CGPoint(x: bx0 + k * 4, y: by + k * 30))
        drawText(&ctx, "\(Int((Double(dash.maxRPM) / 1000).rounded()))", size: k * 16, weight: .bold,
                 italic: false, colour: tick, at: CGPoint(x: bx1 - k * 6, y: by + k * 30))
        drawText(&ctx, "RPM x1000", size: k * 18, weight: .heavy, italic: true,
                 colour: Color(hex: 0xdfe9f0), at: CGPoint(x: (bx0 + bx1) / 2, y: by + k * 32))
    }

    // MARK: Text

    /// As in SVG, `at` is the text baseline; horizontal alignment comes from `anchor`.
    private func drawText(_ ctx: inout GraphicsContext, _ string: String, size: CGFloat,
                          weight: Font.Weight, italic: Bool, colour: Color, tracking: CGFloat = 0,
                          anchor: HorizontalAlignment = .center, at point: CGPoint) {
        var text = Text(verbatim: string)
            .font(.system(size: size, weight: weight))
            .foregroundColor(colour)
            .tracking(tracking)
        if italic { text = text.italic() }
        let resolved = ctx.resolve(text)
        let unit: UnitPoint = anchor == .leading ? .bottomLeading : .bottom
        // Baseline: about 0.22 em of descender space above the bottom edge.
        ctx.draw(resolved, at: CGPoint(x: point.x, y: point.y + size * 0.22), anchor: unit)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255)
    }
}

private extension DashboardModel {
    var speedUnitLabel: String { "KM/H" }
}
