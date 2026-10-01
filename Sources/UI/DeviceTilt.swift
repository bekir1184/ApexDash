import CoreMotion
import SwiftUI
import UIKit

/// Which way the phone is physically held, read from gravity.
///
/// `UIDevice.current.orientation` stops reporting while the user has rotation lock on: the
/// phone can be turned and it still says portrait. Core Motion reads the accelerometer
/// directly and the lock does not affect it. Simulators have no motion hardware, so there
/// the reading falls back to `UIDevice`.
@MainActor
final class DeviceTilt: ObservableObject {
    /// Gravity's angle on the screen plane, snapped to a quarter turn.
    /// Zero holds the phone upright; the angle grows as it turns clockwise.
    @Published private(set) var angle: Double = 0

    /// True while the phone stands upright, either way up.
    var isUpright: Bool { angle == 0 || abs(angle) == 180 }

    private let motion = CMMotionManager()
    private var observer: NSObjectProtocol?

    func start() {
        guard motion.isDeviceMotionAvailable else { return startFallback() }
        guard !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.1
        // The handler is delivered on the main queue, so the reading stays on the actor.
        motion.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let gravity = motion?.gravity else { return }
            MainActor.assumeIsolated { self?.apply(gravity) }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            self.observer = nil
        }
    }

    /// Gravity points down in the world, so its direction on the screen plane says which way
    /// the phone is held. Lying flat there is almost nothing left in that plane, and the
    /// reading is kept as it was.
    private func apply(_ gravity: CMAcceleration) {
        guard hypot(gravity.x, gravity.y) > 0.3 else { return }
        let degrees = atan2(gravity.x, -gravity.y) * 180 / .pi
        // Sticky edges: a phone held near the diagonal should not flicker between two
        // readings, so leaving the current quarter costs ten degrees more than entering it.
        let distance = abs(degrees)
        let limit = isUpright ? 55.0 : 45.0
        let snapped: Double
        switch distance {
        case ..<limit: snapped = 0
        case (180 - limit)...: snapped = 180
        default: snapped = degrees > 0 ? 90 : -90
        }
        guard snapped != angle else { return }
        angle = snapped
    }

    /// Simulator and anything else without motion hardware.
    private func startFallback() {
        guard observer == nil else { return }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        readDevice()
        observer = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.readDevice() }
        }
    }

    private func readDevice() {
        // A device held with its home button on the left reports landscapeRight, and gravity
        // then points along the phone's own right edge: a quarter turn clockwise.
        switch UIDevice.current.orientation {
        case .portrait: angle = 0
        case .portraitUpsideDown: angle = 180
        case .landscapeRight: angle = 90
        case .landscapeLeft: angle = -90
        default: break
        }
    }
}
