import SwiftUI

/// The layer that flashes at the shift point, as on real steering wheels.
struct ShiftFlashOverlay: View {
    let active: Bool
    var color = Color(red: 0.45, green: 0.4, blue: 1.0)

    var body: some View {
        if active {
            TimelineView(.periodic(from: .now, by: 0.07)) { context in
                let on = Int(context.date.timeIntervalSinceReferenceDate / 0.07) % 2 == 0
                Rectangle()
                    .fill(color)
                    .opacity(on ? 0.45 : 0)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
        }
    }
}
