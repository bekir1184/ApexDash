import AVFoundation
import Foundation

/// Blinks the phone's flash in step with the screen at the shift point. Enabled in
/// Settings; while off, the hardware is never touched.
@MainActor
final class ShiftTorch {
    static let shared = ShiftTorch()

    /// Same period as ShiftFlashOverlay on screen.
    private let period: TimeInterval = 0.07
    private var timer: Timer?
    private var lit = false
    private var device: AVCaptureDevice? { AVCaptureDevice.default(for: .video) }

    /// Called whenever the warning state changes.
    func update(active: Bool, enabled: Bool) {
        if active && enabled {
            guard timer == nil else { return }
            // In sync with the screen: the phase comes from the same clock.
            timer = Timer.scheduledTimer(withTimeInterval: period / 2, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    let on = Int(Date().timeIntervalSinceReferenceDate / self.period) % 2 == 0
                    if on != self.lit { self.set(on) }
                }
            }
        } else {
            timer?.invalidate()
            timer = nil
            if lit { set(false) }
        }
    }

    private func set(_ on: Bool) {
        guard let device, device.hasTorch, device.isTorchAvailable else { return }
        do {
            try device.lockForConfiguration()
            if on { try device.setTorchModeOn(level: 1.0) } else { device.torchMode = .off }
            device.unlockForConfiguration()
            lit = on
        } catch {
            lit = false
        }
    }
}
