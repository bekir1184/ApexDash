import AVFoundation
import Foundation

/// Vites uyarisinda telefonun flasini ekranla ayni tempoda yakip sondurur.
/// Ayarlardan acilip kapatilir; kapaliyken donanima hic dokunulmaz.
@MainActor
final class ShiftTorch {
    static let shared = ShiftTorch()

    /// Ekrandaki ShiftFlashOverlay ile ayni periyot.
    private let period: TimeInterval = 0.07
    private var timer: Timer?
    private var lit = false
    private var device: AVCaptureDevice? { AVCaptureDevice.default(for: .video) }

    /// Uyari durumu her degistiginde cagrilir.
    func update(active: Bool, enabled: Bool) {
        if active && enabled {
            guard timer == nil else { return }
            // Ekranla senkron: ayni saat tabanindan faz alinir.
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
