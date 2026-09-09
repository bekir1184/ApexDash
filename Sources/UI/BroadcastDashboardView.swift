import SwiftUI

/// Yayin grafiklerindeki mavi HUD. Geometri, onaylanan SVG prototipinden
/// (2170 x 1000 tasarim alani, R = 340) birebir tasinmistir: ortada nokta
/// dokulu hiz gostergesi, iki yanda cemberle ayni merkezli halka dilimleri
/// (RECHARGE / DEPLOY paneli ve BRAKE / THROTTLE bloklari), altta pil,
/// koselerde surucu plakalari ve vites / devir / aktif aero paneli.
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
                // Vites uyarisi gostergenin (esnetilmis) elipsi icinde yanip soner.
                let frame = layout.centre(BroadcastHUD(dash: dash).dialFrame)
                ShiftFlashOverlay(active: dash.shiftFlash, color: Color(hex: 0x63d6dd))
                    .clipShape(Ellipse())
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
        }
    }
}

/// Orta grup (cember, paneller, bloklar, pil) tasarim yuksekligini ekran
/// yuksekligine oturtur; yan bantlar kalan genislige sigacak sekilde ayri
/// olceklenir ve alt koselere, blok etiketleriyle ayni tabana hizalanir.
struct BroadcastLayout {
    let size: CGSize
    let centreScale: CGFloat
    let bandScale: CGFloat
    let bandWidth: CGFloat
    let bandHeight: CGFloat

    /// Orta grubun tasarim alanindaki dusey araligi: esnetilmis bezel ustu
    /// ile BRAKE / THROTTLE yazisinin alti.
    static let designTop: CGFloat = 20
    static let designBottom: CGFloat = 906
    static let designCentreX: CGFloat = 1085

    init(size: CGSize) {
        self.size = size
        let R: CGFloat = 340
        bandWidth = R * 1.09
        bandHeight = R * 1.0
        let margin = size.width * 0.012
        // Orta grup yuksekligi doldurur; ama yan bantlara ekran genisliginin
        // en az %17'si kalacak sekilde sinirlanir.
        let minBand = size.width * 0.17
        let byHeight = size.height / (Self.designBottom - Self.designTop)
        let byWidth = (size.width / 2 - 2 * margin - minBand) / (R * 2.06)
        centreScale = min(byHeight, byWidth)
        let free = size.width / 2 - R * 2.06 * centreScale - 2 * margin
        bandScale = max(min(centreScale, free / bandWidth), 0.01)
    }

    /// Tasarim koordinatindaki orta grup dikdortgenini ekrana tasir.
    func centre(_ rect: CGRect) -> CGRect {
        let x = size.width / 2 + (rect.minX - Self.designCentreX) * centreScale
        let span = (Self.designBottom - Self.designTop) * centreScale
        let y = (size.height - span) / 2 + (rect.minY - Self.designTop) * centreScale
        return CGRect(x: x, y: y, width: rect.width * centreScale, height: rect.height * centreScale)
    }

    func applyCentre(to ctx: inout GraphicsContext) {
        let origin = centre(CGRect(x: 0, y: 0, width: 0, height: 0)).origin
        ctx.translateBy(x: origin.x, y: origin.y)
        ctx.scaleBy(x: centreScale, y: centreScale)
    }

    /// Bant icin yerel (0,0 kokenli) tasarim koordinatlarini ekrana tasir.
    func applyBand(to ctx: inout GraphicsContext, side: BroadcastHUD.Side, bottomDesignY: CGFloat) {
        let margin = size.width * 0.012
        let bottom = centre(CGRect(x: 0, y: bottomDesignY, width: 0, height: 0)).minY
        let x = side == .left ? margin : size.width - margin - bandWidth * bandScale
        ctx.translateBy(x: x, y: bottom - bandHeight * bandScale)
        ctx.scaleBy(x: bandScale, y: bandScale)
    }
}

// MARK: - Cizim

/// Tasarim alanindaki tum cizim; GraphicsContext uzerine tek gecişte cizer.
struct BroadcastHUD {
    let dash: DashboardModel

    // Prototipteki sabitler
    let R: CGFloat = 340
    let CX: CGFloat = 1085
    let CY: CGFloat = 480
    var corner: CGFloat { R * 0.13 }
    /// Cember, paneller ve bloklar tabandan yukari dogru bu oranda esnetilir.
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

    /// Esnetilmis gostergenin cerceve dikdortgeni (tasarim koordinatlari).
    var dialFrame: CGRect {
        let r = R * 1.03
        let top = stretchBase - (stretchBase - (CY - r)) * stretch
        let bottom = stretchBase - (stretchBase - (CY + r)) * stretch
        return CGRect(x: CX - r, y: top, width: 2 * r, height: bottom - top)
    }

    func draw(in ctx: inout GraphicsContext, layout: BroadcastLayout) {
        var left = ctx
        layout.applyBand(to: &left, side: .left, bottomDesignY: CY + R * 1.22)
        drawDriverPlates(in: &left, size: CGSize(width: layout.bandWidth, height: layout.bandHeight))
        var right = ctx
        layout.applyBand(to: &right, side: .right, bottomDesignY: CY + R * 1.22)
        drawRightBand(in: &right, size: CGSize(width: layout.bandWidth, height: layout.bandHeight))

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

    /// Bu turda kalan harcama payi: tur basinda dolu, harcandikca azalir.
    /// Limit gelmemisse depodaki enerji orani kullanilir.
    private var deployLevel: Double {
        dash.ersHarvestLimitPerLap > 0 ? 1 - dash.deployedFraction : dash.ersFraction
    }

    private var deployActive: Bool { dash.ersTrend < 0 }

    private func litCount(_ fraction: Double) -> Int {
        Int((min(max(fraction, 0), 1) * 10).rounded())
    }

    // MARK: Halka dilimi geometrisi

    enum Side { case left, right }

    /// Prototipteki P(r, a): sol tarafta x ekseni aynalanir.
    private func point(_ side: Side, _ r: CGFloat, _ a: CGFloat) -> CGPoint {
        CGPoint(x: CX + (side == .left ? -1 : 1) * r * cos(a), y: CY + r * sin(a))
    }

    private func angle(_ side: Side, _ a: CGFloat) -> Angle {
        .radians(side == .left ? Double(.pi - a) : Double(a))
    }

    /// Ic yay a0 -> a1, dis yay a1 -> a0 olan halka dilimi.
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

    /// Koseleri yuvarlatilmis dilim: sekil `c` kadar icten cizilir ve ayni
    /// renkte 2c kalinliginda yuvarlak birlesimli konturla boyutuna doner.
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

    // MARK: BRAKE / THROTTLE bloklari

    private func drawSlatBlock(in ctx: inout GraphicsContext, side: Side, lit: Int,
                               colour: Color, label: String) {
        let rIn = R * 1.58, rOut = R * 1.96, rMid = (rIn + rOut) / 2
        let aTop = -asin(0.40 * R / rMid), aBottom = asin(0.91 * R / rMid)
        let seg = roundedSegment(side, rIn: rIn, rOut: rOut, aTop: aTop, aBottom: aBottom, c: corner)

        fillRounded(&ctx, seg, .color(blockFill))
        strokeRounded(&ctx, seg, blockEdge.opacity(0.8), extra: 2.5)
        fillRounded(&ctx, seg, .color(blockFill), widthDelta: -2.5)

        // Dilimler, blogun padR kadar icten yuvarlatilmis kopyasiyla maskelenir.
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

    // MARK: RECHARGE / DEPLOY panelleri

    private func drawLabelPanel(in ctx: inout GraphicsContext, side: Side, text: String,
                                level: Double, active: Bool) {
        let rIn = R * 1.125, rOut = R * 1.52, rMid = (rIn + rOut) / 2
        let aTop = -asin(0.56 * R / rMid), aBottom = asin(0.88 * R / rMid)
        let seg = roundedSegment(side, rIn: rIn, rOut: rOut, aTop: aTop, aBottom: aBottom, c: corner)

        let top = point(side, rMid, aTop).y, bottom = point(side, rMid, aBottom).y
        // Sonuk taban; ustune alttan yukari seviye kadar dolgu. Aktifken
        // panel parlak maviye doner, disina isik sizar ve harfler beyazlasir.
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

        // Harfler orta yaricap boyunca, dik, esit acisal aralikla
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

    // MARK: Cember

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

        // Halka konturlari pile yaklastikca solar.
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

        // Cember ici
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
        let available = dash.overtakeAvailable || dash.overtakeActive
        ctx.fill(box, with: .color(dash.overtakeActive ? green : Color(hex: 0x0b2a16)))
        ctx.stroke(box, with: .color(green.opacity(available ? 1 : 0.3)), lineWidth: 5)
        drawText(&ctx, "OVERTAKE", size: 52, weight: .bold, italic: false,
                 colour: dash.overtakeActive ? .black : green.opacity(available ? 1 : 0.35), tracking: 2,
                 at: CGPoint(x: CX, y: CY + R * 0.43))
        _ = centre
    }

    // MARK: Pil

    private func drawBattery(in ctx: inout GraphicsContext) {
        let bw = R * 0.80, bh = R * 0.24, by = CY + R * 0.86
        let rect = CGRect(x: CX - bw / 2, y: by, width: bw, height: bh)
        let body = Path(roundedRect: rect, cornerRadius: bh * 0.30)
        // Oyundaki gibi: normalde sari, Overtake devredeyken maviye doner.
        let blue = dash.overtakeActive
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

        // Simsek
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

    // MARK: Yan bantlar

    private struct Band {
        let rect: CGRect
        var x0: CGFloat { rect.minX }
        var w: CGFloat { rect.width }
        var h: CGFloat { rect.height }
    }

    private func drawSideBand(in ctx: inout GraphicsContext, size: CGSize) -> Band {
        let inset: CGFloat = 2
        let rect = CGRect(x: inset, y: inset, width: size.width - 2 * inset, height: size.height - 2 * inset)
        let path = Path(roundedRect: rect, cornerRadius: corner)
        ctx.fill(path, with: .color(blockFill))
        ctx.stroke(path, with: .color(blockEdge), lineWidth: 3)
        return Band(rect: rect)
    }

    private func drawDriverPlates(in ctx: inout GraphicsContext, size: CGSize) {
        let band = drawSideBand(in: &ctx, size: size)
        let pad = R * 0.08
        let rows: [Rival?] = [dash.driverAhead, dash.player, dash.driverBehind]
        for (i, rival) in rows.enumerated() {
            let y = band.rect.minY + band.h * (0.26 + 0.30 * CGFloat(i))
            var line = Path()
            line.move(to: CGPoint(x: band.rect.minX + pad, y: y + R * 0.05))
            line.addLine(to: CGPoint(x: band.rect.maxX - pad, y: y + R * 0.05))
            ctx.stroke(line, with: .color(teal.opacity(rival == nil ? 0.35 : 1)), lineWidth: 3)
            guard let rival else { continue }
            let isPlayer = i == 1
            drawText(&ctx, "\(rival.position)", size: 34, weight: .heavy, italic: true, colour: cyanInk,
                     anchor: .leading, at: CGPoint(x: band.rect.minX + pad, y: y))
            drawText(&ctx, rival.name.uppercased(), size: 40, weight: .heavy, italic: true,
                     colour: isPlayer ? cyanInk : .white, anchor: .leading,
                     at: CGPoint(x: band.rect.minX + pad + R * 0.22, y: y))
        }
    }

    private func drawRightBand(in ctx: inout GraphicsContext, size: CGSize) {
        let band = drawSideBand(in: &ctx, size: size)
        let pad = R * 0.08, x0 = band.rect.minX + pad, x1 = band.rect.maxX - pad

        // Satir 1: ACTIVE AERO + cift cizgi
        let y1 = band.rect.minY + band.h * 0.22
        let aero = dash.aeroStraightMode
        drawText(&ctx, "ACTIVE AERO", size: 30, weight: .heavy, italic: true,
                 colour: aero ? .white : Color(hex: 0x6f8797), anchor: .leading,
                 at: CGPoint(x: x0, y: y1))
        var slashes = Path()
        slashes.move(to: CGPoint(x: x1 - 46, y: y1 + 2)); slashes.addLine(to: CGPoint(x: x1 - 30, y: y1 - 20))
        slashes.move(to: CGPoint(x: x1 - 22, y: y1 + 2)); slashes.addLine(to: CGPoint(x: x1 - 6, y: y1 - 20))
        ctx.stroke(slashes, with: .color(aero ? Color(hex: 0x3fe0f0) : Color(hex: 0x3d5566)),
                   style: StrokeStyle(lineWidth: 5, lineCap: .round))

        // Satir 2: vites cetveli
        let gears = ["N"] + (1...max(dash.maxGears, 8)).map(String.init)
        let y2 = band.rect.minY + band.h * 0.55
        for (i, label) in gears.enumerated() {
            let x = x0 + 18 + (x1 - x0 - 36) * CGFloat(i) / CGFloat(gears.count - 1)
            let on = label == dash.gearLabel
            drawText(&ctx, label, size: 40, weight: .heavy, italic: true,
                     colour: on ? .white : Color(hex: 0x4d6a7c), at: CGPoint(x: x, y: y2))
        }

        // Satir 3: RPM cubugu
        let by = band.rect.minY + band.h * 0.70
        let track = Path(roundedRect: CGRect(x: x0, y: by, width: x1 - x0, height: 8), cornerRadius: 4)
        ctx.fill(track, with: .color(slatOff))
        let fraction = min(max(Double(dash.rpm) / Double(max(dash.maxRPM, 1)), 0), 1)
        if fraction > 0 {
            ctx.fill(Path(roundedRect: CGRect(x: x0, y: by, width: (x1 - x0) * fraction, height: 8),
                          cornerRadius: 4),
                     with: .color(dash.shiftFlash ? .white : teal))
        }
        let tick = Color(hex: 0x9fb6c4)
        drawText(&ctx, "0", size: 22, weight: .bold, italic: false, colour: tick,
                 at: CGPoint(x: x0 + 6, y: by + 32))
        drawText(&ctx, "\(Int((Double(dash.maxRPM) / 1000).rounded()))", size: 22, weight: .bold,
                 italic: false, colour: tick, at: CGPoint(x: x1 - 8, y: by + 32))
        drawText(&ctx, "RPM x1000", size: 30, weight: .heavy, italic: true,
                 colour: Color(hex: 0xdfe9f0), at: CGPoint(x: (x0 + x1) / 2, y: by + 34))
    }

    // MARK: Metin

    /// SVG'deki gibi `at` metnin taban cizgisi; x hizasi `anchor` ile secilir.
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
        // Taban cizgisi: alt kenar ile arasinda yaklasik 0.22 em inis payi var.
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
