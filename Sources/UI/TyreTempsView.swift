import SwiftUI

/// Tyre and brake temperatures for the four corners. Wheel order in the specification: 0 =
/// RL, 1 = RR, 2 = FL, 3 = FR.
struct TyreTempsView: View {
    let tyreSurface: [Int]
    let tyreInner: [Int]
    let brakes: [Int]
    var unit: CGFloat
    var innerLabel: String
    var compact: Bool = false

    private enum Corner: Int, CaseIterable {
        case frontLeft = 2, frontRight = 3, rearLeft = 0, rearRight = 1
        var label: String {
            switch self {
            case .frontLeft: return "FL"
            case .frontRight: return "FR"
            case .rearLeft: return "RL"
            case .rearRight: return "RR"
            }
        }
    }

    var body: some View {
        VStack(spacing: unit * 0.18) {
            HStack(spacing: unit * 0.18) {
                corner(.frontLeft)
                corner(.frontRight)
            }
            HStack(spacing: unit * 0.18) {
                corner(.rearLeft)
                corner(.rearRight)
            }
        }
    }

    private func corner(_ corner: Corner) -> some View {
        let index = corner.rawValue
        let surface = tyreSurface.indices.contains(index) ? tyreSurface[index] : 0
        let inner = tyreInner.indices.contains(index) ? tyreInner[index] : 0
        let brake = brakes.indices.contains(index) ? brakes[index] : 0

        return VStack(spacing: 1) {
            if !compact {
                Text(corner.label)
                    .font(.system(size: unit * 0.2, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text(verbatim: "\(surface)°")
                .font(.system(size: unit * 0.42, weight: .black, design: .monospaced))
                .foregroundStyle(TempScale.tyre(surface))
            if !compact {
                Text(verbatim: "\(inner)° \(innerLabel)")
                    .font(.system(size: unit * 0.19, weight: .semibold, design: .monospaced))
                    .foregroundStyle(TempScale.tyre(inner).opacity(0.6))
            }
            Text(verbatim: "\(brake)°")
                .font(.system(size: unit * 0.26, weight: .bold, design: .monospaced))
                .foregroundStyle(TempScale.brake(brake))
        }
        .frame(width: unit * 1.35)
        .padding(.vertical, unit * 0.12)
        .background(
            RoundedRectangle(cornerRadius: unit * 0.14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: unit * 0.14, style: .continuous)
                .stroke(TempScale.tyre(surface).opacity(0.45), lineWidth: 1)
        )
    }
}
