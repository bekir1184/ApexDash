import SwiftUI

/// Seksenlerin dijital gosterge paneli: siyah zemin uzerinde kirmizi parlayan
/// yedi parcali rakamlar, dort cerceveli bolme ve tarama cizgileri.
struct RetroDashboardView: View {
    let dash: DashboardModel
    let unit: CGFloat

    var body: some View {
        GeometryReader { geo in
            Canvas(rendersAsynchronously: false) { context, size in
                let hud = RetroHUD(dash: dash, size: size)
                // Once bulanik bir kopya cizilir: tuplerin cevresindeki isima.
                var glow = context
                glow.addFilter(.blur(radius: size.height * 0.011))
                glow.opacity = 0.85
                hud.draw(in: &glow)
                hud.draw(in: &context)
                hud.drawScanlines(in: &context)
            }
        }
    }
}

/// Butun cizim. Olculer kutu yuksekligine gore verilir, boylece her ekranda
/// ayni oranlarda durur.
struct RetroHUD {
    let dash: DashboardModel
    let size: CGSize

    // Fosfor kirmizisi: parlak, sonuk ve cerceve tonlari.
    let bright = Color(red: 1.0, green: 0.27, blue: 0.16)
    let mid = Color(red: 0.85, green: 0.18, blue: 0.10)
    let dim = Color(red: 1.0, green: 0.27, blue: 0.16).opacity(0.13)
    let frame = Color(red: 0.55, green: 0.12, blue: 0.07)

    func draw(in ctx: inout GraphicsContext) {
        let pad = size.height * 0.05
        let gap = size.width * 0.012
        // Bolme genislikleri: son bolme biraz daha genis.
        let weights: [CGFloat] = [0.82, 1.3, 1.45]
        let usable = size.width - 2 * pad - gap * CGFloat(weights.count - 1)
        let total = weights.reduce(0, +)

        var x = pad
        var frames: [CGRect] = []
        for w in weights {
            let width = usable * w / total
            frames.append(CGRect(x: x, y: pad, width: width, height: size.height - 2 * pad))
            x += width + gap
        }

        drawVitals(in: &ctx, rect: panel(&ctx, frames[0], "VEHICLE VITALS"))
        drawTacho(in: &ctx, rect: panel(&ctx, frames[1], "TACHOMETER"))
        drawSpeedAndLap(in: &ctx, rect: panel(&ctx, frames[2], "SPEED & LAP"))
    }

    /// Cerceve ve ustundeki baslik; geriye icerik alanini dondurur.
    private func panel(_ ctx: inout GraphicsContext, _ rect: CGRect, _ title: String) -> CGRect {
        let radius = rect.height * 0.06
        let box = Path(roundedRect: rect, cornerRadius: radius)

        // Kareli zemin, cerceveye kirpilir.
        var inside = ctx
        inside.clip(to: box)
        var grid = Path()
        let step = rect.height * 0.072
        var gx = rect.minX
        while gx < rect.maxX { grid.move(to: CGPoint(x: gx, y: rect.minY))
                               grid.addLine(to: CGPoint(x: gx, y: rect.maxY)); gx += step }
        var gy = rect.minY
        while gy < rect.maxY { grid.move(to: CGPoint(x: rect.minX, y: gy))
                               grid.addLine(to: CGPoint(x: rect.maxX, y: gy)); gy += step }
        inside.stroke(grid, with: .color(frame.opacity(0.32)), lineWidth: max(0.5, rect.height * 0.003))

        ctx.stroke(box, with: .color(frame), lineWidth: max(1, rect.height * 0.008))

        let titleHeight = rect.height * 0.15
        let track = rect.height * 0.01
        let titleSize = fitted(title, size: rect.height * 0.075,
                               width: rect.width * 0.82, tracking: track)
        text(&ctx, title, size: titleSize, colour: bright, tracking: track,
             at: CGPoint(x: rect.midX, y: rect.minY + titleHeight * 0.72))
        var line = Path()
        line.move(to: CGPoint(x: rect.minX, y: rect.minY + titleHeight))
        line.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + titleHeight))
        ctx.stroke(line, with: .color(frame), lineWidth: max(1, rect.height * 0.006))

        let inset = rect.height * 0.05
        return CGRect(x: rect.minX + inset, y: rect.minY + titleHeight + inset,
                      width: rect.width - 2 * inset,
                      height: rect.height - titleHeight - 2 * inset)
    }

    // MARK: Bolme 1 - sicakliklar ve ERS

    private func drawVitals(in ctx: inout GraphicsContext, rect: CGRect) {
        let barsWidth = rect.width * 0.42
        let barArea = CGRect(x: rect.minX, y: rect.minY,
                             width: barsWidth, height: rect.height * 0.64)
        bar(&ctx, rect: CGRect(x: barArea.minX, y: barArea.minY,
                               width: barArea.width * 0.38, height: barArea.height),
            fraction: level(dash.averageTyreTemp, from: 60, to: 130))
        bar(&ctx, rect: CGRect(x: barArea.minX + barArea.width * 0.55, y: barArea.minY,
                               width: barArea.width * 0.38, height: barArea.height),
            fraction: level(dash.averageBrakeTemp, from: 150, to: 950))

        // Cubuklarin sagindaki etiketler, referanstaki gibi H ve L uclu.
        let labelX = rect.minX + barsWidth + rect.width * 0.18
        let rowH = rect.height * 0.30
        label(&ctx, "TYRE TEMP", at: CGPoint(x: labelX, y: rect.minY + rowH * 0.32), rect: rect)
        scale(&ctx, x: labelX - rect.width * 0.15, top: rect.minY + rowH * 0.42,
              height: rowH * 0.5, rect: rect)
        label(&ctx, "BRAKE TEMP", at: CGPoint(x: labelX, y: rect.minY + rowH * 1.12), rect: rect)
        scale(&ctx, x: labelX - rect.width * 0.15, top: rect.minY + rowH * 1.22,
              height: rowH * 0.5, rect: rect)

        // Alt satir: ERS deposu, referanstaki voltaj gostergesi gibi.
        let footY = rect.maxY - rect.height * 0.16
        var line = Path()
        line.move(to: CGPoint(x: rect.minX, y: footY - rect.height * 0.13))
        line.addLine(to: CGPoint(x: rect.maxX, y: footY - rect.height * 0.13))
        ctx.stroke(line, with: .color(frame), lineWidth: max(1, rect.height * 0.005))
        text(&ctx, "ERS", size: rect.height * 0.09, colour: bright,
             anchor: .leading, at: CGPoint(x: rect.minX, y: footY))
        let percent = Int((dash.ersFraction * 100).rounded())
        segments(&ctx, String(format: "%3d", percent),
                 rect: CGRect(x: rect.minX + rect.width * 0.42, y: footY - rect.height * 0.15,
                              width: rect.width * 0.38, height: rect.height * 0.17))
        text(&ctx, "%", size: rect.height * 0.085, colour: mid,
             anchor: .trailing, at: CGPoint(x: rect.maxX, y: footY))
    }

    private func bar(_ ctx: inout GraphicsContext, rect: CGRect, fraction: Double) {
        let blocks = 12
        let gap = rect.height * 0.016
        let h = (rect.height - gap * CGFloat(blocks - 1)) / CGFloat(blocks)
        let lit = Int((min(max(fraction, 0), 1) * Double(blocks)).rounded())
        for i in 0..<blocks {
            let y = rect.maxY - CGFloat(i + 1) * h - CGFloat(i) * gap
            let block = Path(CGRect(x: rect.minX, y: y, width: rect.width, height: h))
            ctx.fill(block, with: .color(i < lit ? bright : dim))
        }
    }

    private func scale(_ ctx: inout GraphicsContext, x: CGFloat, top: CGFloat,
                       height: CGFloat, rect: CGRect) {
        text(&ctx, "H", size: rect.height * 0.07, colour: mid,
             anchor: .leading, at: CGPoint(x: x, y: top))
        text(&ctx, "L", size: rect.height * 0.07, colour: mid,
             anchor: .leading, at: CGPoint(x: x, y: top + height))
        var ticks = Path()
        for i in 0...4 {
            let y = top - rect.height * 0.02 + height * CGFloat(i) / 4
            ticks.move(to: CGPoint(x: x + rect.width * 0.12, y: y))
            ticks.addLine(to: CGPoint(x: x + rect.width * 0.2, y: y))
        }
        ctx.stroke(ticks, with: .color(frame), lineWidth: max(1, rect.height * 0.008))
    }

    // MARK: Bolme 2 - devir saati

    private func drawTacho(in ctx: inout GraphicsContext, rect: CGRect) {
        let radius = min(rect.width * 0.44, rect.height * 0.42)
        // Yarim daire dikeyde ortalansin: merkez, yayin alt kenari olur.
        let centre = CGPoint(x: rect.midX, y: rect.midY + radius * 0.55)
        let inner = radius * 0.58
        let steps = 22
        let fraction = min(max(Double(dash.rpm) / Double(max(dash.maxRPM, 1)), 0), 1)
        let lit = Int((fraction * Double(steps)).rounded())

        for i in 0..<steps {
            let a0 = Double.pi + Double(i) * Double.pi / Double(steps) + 0.012
            let a1 = Double.pi + Double(i + 1) * Double.pi / Double(steps) - 0.012
            var seg = Path()
            seg.addArc(center: centre, radius: inner, startAngle: .radians(a0),
                       endAngle: .radians(a1), clockwise: false)
            seg.addArc(center: centre, radius: radius, startAngle: .radians(a1),
                       endAngle: .radians(a0), clockwise: true)
            seg.closeSubpath()
            ctx.fill(seg, with: .color(i < lit ? bright : dim))
        }

        // Olcek sayilari: devir bininci basamakta.
        let maxK = max(dash.maxRPM / 1000, 1)
        for i in 0...5 {
            let t = Double(i) / 5
            let a = Double.pi + t * Double.pi
            let r = radius * 1.26
            let p = CGPoint(x: centre.x + r * CGFloat(cos(a)),
                            y: centre.y + r * CGFloat(sin(a)) + rect.height * 0.03)
            text(&ctx, "\(Int((Double(maxK) * t).rounded()))",
                 size: rect.height * 0.08, colour: mid, at: p)
        }

        segments(&ctx, dash.gearLabel,
                 rect: CGRect(x: centre.x - inner * 0.36, y: centre.y - inner * 0.94,
                              width: inner * 0.72, height: inner * 0.9))
        // Yayin disina tirnaklar, referanstaki gibi.
        var ticks = Path()
        for i in 0...20 {
            let a = Double.pi + Double(i) * Double.pi / 20
            let long = i % 5 == 0
            let r0 = radius * 1.02, r1 = radius * (long ? 1.13 : 1.08)
            ticks.move(to: CGPoint(x: centre.x + r0 * CGFloat(cos(a)),
                                   y: centre.y + r0 * CGFloat(sin(a))))
            ticks.addLine(to: CGPoint(x: centre.x + r1 * CGFloat(cos(a)),
                                      y: centre.y + r1 * CGFloat(sin(a))))
        }
        ctx.stroke(ticks, with: .color(mid), lineWidth: max(1, rect.height * 0.006))

        text(&ctx, "x1000 RPM", size: rect.height * 0.062, colour: mid,
             at: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.01))
    }

    // MARK: Bolme 3 - hiz ve tur

    private func drawSpeedAndLap(in ctx: inout GraphicsContext, rect: CGRect) {
        // Ust yari: hiz, bolmenin kahramani.
        let speedBox = CGRect(x: rect.minX, y: rect.minY,
                              width: rect.width * 0.62, height: rect.height * 0.52)
        segments(&ctx, String(format: "%3d", min(dash.speedKPH, 999)), rect: speedBox)
        text(&ctx, "KM/H", size: rect.height * 0.075, colour: mid,
             at: CGPoint(x: speedBox.midX, y: speedBox.maxY + rect.height * 0.06))

        // Sagda tur suresi ve fark.
        let side = CGRect(x: rect.minX + rect.width * 0.66, y: rect.minY,
                          width: rect.width * 0.34, height: rect.height * 0.52)
        segments(&ctx, lapClock,
                 rect: CGRect(x: side.minX, y: side.minY + side.height * 0.06,
                              width: side.width, height: side.height * 0.34))
        text(&ctx, "DELTA", size: rect.height * 0.055, colour: mid,
             at: CGPoint(x: side.midX, y: side.minY + side.height * 0.62))
        let delta = dash.deltaToBestText
        text(&ctx, delta, size: fitted(delta, size: rect.height * 0.105, width: side.width),
             colour: bright, at: CGPoint(x: side.midX, y: side.minY + side.height * 0.8))

        var line = Path()
        line.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.64))
        line.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.64))
        ctx.stroke(line, with: .color(frame), lineWidth: max(1, rect.height * 0.005))

        // Alt satir: sira, tur, yakit ve gerekirse pit uyarisi.
        let footY = rect.maxY - rect.height * 0.06
        let quarter = rect.width / 4
        cell(&ctx, "POS", "P\(dash.carPosition)", x: rect.minX + quarter * 0.5, y: footY, rect: rect)
        cell(&ctx, "LAP", "\(dash.currentLapNum)", x: rect.minX + quarter * 1.5, y: footY, rect: rect)
        cell(&ctx, "FUEL", String(format: "%.1f", dash.fuelRemainingLaps),
             x: rect.minX + quarter * 2.5, y: footY, rect: rect)
        cell(&ctx, dash.pitLimiterOn ? "PIT" : "BEST",
             dash.pitLimiterOn ? "ON" : shortLap(dash.bestLapMS),
             x: rect.minX + quarter * 3.5, y: footY, rect: rect)
    }

    private func cell(_ ctx: inout GraphicsContext, _ name: String, _ value: String,
                      x: CGFloat, y: CGFloat, rect: CGRect) {
        let width = rect.width / 4 * 0.92
        text(&ctx, name, size: fitted(name, size: rect.height * 0.07, width: width),
             colour: mid, at: CGPoint(x: x, y: y - rect.height * 0.09))
        text(&ctx, value, size: fitted(value, size: rect.height * 0.12, width: width),
             colour: bright, at: CGPoint(x: x, y: y + rect.height * 0.04))
    }

    /// Dar hucreler icin kisa tur suresi: 1:28.6 gibi.
    private func shortLap(_ ms: Int) -> String {
        guard ms > 0 else { return "--.-" }
        return String(format: "%d:%02d.%d", ms / 60_000, (ms % 60_000) / 1000, (ms % 1000) / 100)
    }

    /// Tur suresi: dakika, saniye ve salise, iki nokta ile.
    private var lapClock: String {
        let ms = dash.currentLapTimeMS
        let m = ms / 60_000, s = (ms % 60_000) / 1000, t = (ms % 1000) / 100
        return String(format: "%d:%02d.%d", m, s, t)
    }

    // MARK: Yedi parcali rakamlar

    /// Verilen metni kutuya sigacak sekilde yedi parcali basamaklarla cizer.
    /// Yanmayan parcalar sonuk birakilir: gercek gostergelerdeki gibi.
    private func segments(_ ctx: inout GraphicsContext, _ string: String, rect: CGRect) {
        let chars = Array(string)
        // Iki nokta ve nokta dar, rakamlar genis.
        let widths = chars.map { c -> CGFloat in ":.".contains(c) ? 0.34 : 1.0 }
        let gapRatio: CGFloat = 0.2
        let units = widths.reduce(0, +) + gapRatio * CGFloat(max(chars.count - 1, 0))
        // Basamak, hem kutunun genisligine hem de yuksekliginin yarisina sigar.
        // Bir basamagin en-boy orani gercek gostergelerdeki gibi ~1:1.8.
        let aspect: CGFloat = 1.8
        let digitW = min(rect.width / units, rect.height / aspect)
        let digitH = digitW * aspect
        let used = digitW * units
        let thickness = digitW * 0.2

        var x = rect.minX + (rect.width - used) / 2
        let top = rect.minY + (rect.height - digitH) / 2
        for (i, c) in chars.enumerated() {
            let w = digitW * widths[i]
            let box = CGRect(x: x, y: top, width: w, height: digitH)
            if c == ":" {
                let r = thickness * 0.5
                for cy in [box.midY - box.height * 0.22, box.midY + box.height * 0.22] {
                    ctx.fill(Path(ellipseIn: CGRect(x: box.midX - r, y: cy - r,
                                                    width: 2 * r, height: 2 * r)),
                             with: .color(bright))
                }
            } else if c == "." {
                let r = thickness * 0.5
                ctx.fill(Path(ellipseIn: CGRect(x: box.midX - r, y: box.maxY - 2 * r,
                                                width: 2 * r, height: 2 * r)),
                         with: .color(bright))
            } else {
                digit(&ctx, c, box: box, thickness: thickness)
            }
            x += w + digitW * gapRatio
        }
    }

    /// Bir basamagin yedi parcasi. Harfler icin alisildik yaklasimlar kullanilir.
    private func digit(_ ctx: inout GraphicsContext, _ c: Character,
                       box: CGRect, thickness t: CGFloat) {
        let on: Set<Int>
        switch c {
        case "0": on = [0, 1, 2, 3, 4, 5]
        case "1": on = [1, 2]
        case "2": on = [0, 1, 3, 4, 6]
        case "3": on = [0, 1, 2, 3, 6]
        case "4": on = [1, 2, 5, 6]
        case "5": on = [0, 2, 3, 5, 6]
        case "6": on = [0, 2, 3, 4, 5, 6]
        case "7": on = [0, 1, 2]
        case "8": on = [0, 1, 2, 3, 4, 5, 6]
        case "9": on = [0, 1, 2, 3, 5, 6]
        case "N": on = [1, 2, 4, 5]          // gostergelerdeki alisildik N
        case "R": on = [4, 6]                // kucuk r
        case "-": on = [6]
        case "+": on = [6]
        default:  on = []
        }

        let w = box.width, h = box.height
        let midY = box.midY
        // Yatay ve dikey parcalar, uclari pahli altigen olarak cizilir.
        func horizontal(_ y: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: box.minX + t * 0.6, y: y))
            p.addLine(to: CGPoint(x: box.minX + t, y: y - t / 2))
            p.addLine(to: CGPoint(x: box.maxX - t, y: y - t / 2))
            p.addLine(to: CGPoint(x: box.maxX - t * 0.6, y: y))
            p.addLine(to: CGPoint(x: box.maxX - t, y: y + t / 2))
            p.addLine(to: CGPoint(x: box.minX + t, y: y + t / 2))
            p.closeSubpath()
            return p
        }
        func vertical(_ x: CGFloat, _ top: CGFloat, _ bottom: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: x, y: top + t * 0.6))
            p.addLine(to: CGPoint(x: x + t / 2, y: top + t))
            p.addLine(to: CGPoint(x: x + t / 2, y: bottom - t))
            p.addLine(to: CGPoint(x: x, y: bottom - t * 0.6))
            p.addLine(to: CGPoint(x: x - t / 2, y: bottom - t))
            p.addLine(to: CGPoint(x: x - t / 2, y: top + t))
            p.closeSubpath()
            return p
        }

        let paths = [
            horizontal(box.minY + t / 2),                                   // 0 ust
            vertical(box.maxX - t / 2, box.minY, midY),                     // 1 sag ust
            vertical(box.maxX - t / 2, midY, box.maxY),                     // 2 sag alt
            horizontal(box.maxY - t / 2),                                   // 3 alt
            vertical(box.minX + t / 2, midY, box.maxY),                     // 4 sol alt
            vertical(box.minX + t / 2, box.minY, midY),                     // 5 sol ust
            horizontal(midY)                                                // 6 orta
        ]
        for (i, path) in paths.enumerated() {
            ctx.fill(path, with: .color(on.contains(i) ? bright : dim))
        }
        _ = w; _ = h
    }

    // MARK: Yazi ve doku

    /// Verilen genislige sigacak en buyuk punto.
    private func fitted(_ string: String, size: CGFloat, width: CGFloat,
                        tracking: CGFloat = 0) -> CGFloat {
        let count = CGFloat(max(string.count, 1))
        let needed = count * (size * 0.62 + tracking)
        return needed <= width ? size : max(size * width / needed, size * 0.4)
    }

    private func text(_ ctx: inout GraphicsContext, _ string: String, size: CGFloat,
                      colour: Color, tracking: CGFloat = 0,
                      anchor: HorizontalAlignment = .center, at point: CGPoint) {
        let resolved = ctx.resolve(
            Text(verbatim: string)
                .font(.system(size: size, weight: .bold, design: .monospaced))
                .foregroundColor(colour)
                .tracking(tracking))
        let unit: UnitPoint = anchor == .leading ? .bottomLeading
                            : anchor == .trailing ? .bottomTrailing : .bottom
        ctx.draw(resolved, at: point, anchor: unit)
    }

    private func label(_ ctx: inout GraphicsContext, _ string: String,
                       at point: CGPoint, rect: CGRect) {
        let width = rect.maxX - point.x
        text(&ctx, string, size: fitted(string, size: rect.height * 0.075, width: width),
             colour: bright, anchor: .leading, at: point)
    }

    private func level(_ value: Int, from low: Int, to high: Int) -> Double {
        Double(value - low) / Double(max(high - low, 1))
    }

    /// Tarama cizgileri: eski tup ekranlardaki yatay bantlar.
    func drawScanlines(in ctx: inout GraphicsContext) {
        var lines = Path()
        var y: CGFloat = 0
        let step = max(2, size.height * 0.006)
        while y < size.height {
            lines.addRect(CGRect(x: 0, y: y, width: size.width, height: step * 0.4))
            y += step
        }
        ctx.fill(lines, with: .color(.black.opacity(0.22)))
    }
}
