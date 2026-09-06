import SwiftUI

/// Ustten gorunumlu arac semasi. Hasar alan parca kirmizi yanar, digerleri sonuk.
struct CarDiagram: View {
    let highlighted: CarPart?
    var severe: Bool = false

    private var accent: Color {
        severe ? Color(red: 1.0, green: 0.19, blue: 0.16) : Color(red: 1.0, green: 0.65, blue: 0.15)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                part(.frontWingLeft, CGRect(x: 0.12, y: 0.02, width: 0.38, height: 0.07), w, h)
                part(.frontWingRight, CGRect(x: 0.50, y: 0.02, width: 0.38, height: 0.07), w, h)
                part(nil, CGRect(x: 0.44, y: 0.09, width: 0.12, height: 0.22), w, h)      // burun
                part(.tyreFL, CGRect(x: 0.06, y: 0.14, width: 0.16, height: 0.16), w, h)
                part(.tyreFR, CGRect(x: 0.78, y: 0.14, width: 0.16, height: 0.16), w, h)
                part(.floor, CGRect(x: 0.40, y: 0.30, width: 0.20, height: 0.42), w, h)
                part(.sidepod, CGRect(x: 0.24, y: 0.36, width: 0.12, height: 0.26), w, h)
                part(.sidepod, CGRect(x: 0.64, y: 0.36, width: 0.12, height: 0.26), w, h)
                part(.engine, CGRect(x: 0.42, y: 0.58, width: 0.16, height: 0.14), w, h)
                part(.gearBox, CGRect(x: 0.44, y: 0.72, width: 0.12, height: 0.08), w, h)
                part(.tyreRL, CGRect(x: 0.06, y: 0.62, width: 0.16, height: 0.17), w, h)
                part(.tyreRR, CGRect(x: 0.78, y: 0.62, width: 0.16, height: 0.17), w, h)
                part(.diffuser, CGRect(x: 0.36, y: 0.80, width: 0.28, height: 0.06), w, h)
                part(.rearWing, CGRect(x: 0.18, y: 0.87, width: 0.64, height: 0.08), w, h)
            }
        }
    }

    private func part(_ id: CarPart?, _ frame: CGRect, _ w: CGFloat, _ h: CGFloat) -> some View {
        let lit = id != nil && id == highlighted
        return RoundedRectangle(cornerRadius: min(w, h) * 0.03, style: .continuous)
            .fill(lit ? accent : Color.white.opacity(0.16))
            .frame(width: frame.width * w, height: frame.height * h)
            .position(x: (frame.minX + frame.width / 2) * w, y: (frame.minY + frame.height / 2) * h)
            .shadow(color: lit ? accent.opacity(0.9) : .clear, radius: min(w, h) * 0.05)
    }
}

/// Hasar aninda beliren, birkac saniye sonra kaybolan uyari.
struct DamageFlashView: View {
    let alert: DamageAlert
    let unit: CGFloat
    @State private var pulse = false

    private var accent: Color {
        alert.isSevere ? Color(red: 1.0, green: 0.19, blue: 0.16) : Color(red: 1.0, green: 0.65, blue: 0.15)
    }

    var body: some View {
        HStack(spacing: unit * 0.3) {
            CarDiagram(highlighted: alert.part, severe: alert.isSevere)
                .frame(width: unit * 1.5, height: unit * 2.1)
            VStack(alignment: .leading, spacing: unit * 0.06) {
                Text("HASAR")
                    .font(.system(size: unit * 0.28, weight: .heavy, design: .monospaced))
                    .foregroundStyle(accent)
                    .tracking(3)
                Text(alert.part.title)
                    .font(.system(size: unit * 0.46, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text(verbatim: "+\(alert.delta)%  ·  TOPLAM \(alert.total)%")
                    .font(.system(size: unit * 0.3, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, unit * 0.4)
        .padding(.vertical, unit * 0.22)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.2, style: .continuous)
                .fill(Color.black.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.2, style: .continuous)
                .stroke(accent.opacity(pulse ? 1 : 0.35), lineWidth: 2.5)
        )
        .shadow(color: accent.opacity(0.5), radius: unit * 0.3)
        .task {
            while !Task.isCancelled {
                pulse.toggle()
                try? await Task.sleep(nanoseconds: 320_000_000)
            }
        }
    }
}
