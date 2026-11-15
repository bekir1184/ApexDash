import Foundation

/// A closed circuit of straights and constant-radius corners, precomputed at
/// one metre resolution. Shared by the demo drives of every game.
struct DemoTrack {
    struct Point {
        let x, z, yaw, curvature, targetSpeed: Double
    }

    let length: Double
    private let points: [Point]

    /// - Parameters:
    ///   - topSpeed: km/h on the straights.
    ///   - grip: lateral grip in g, which sets the corner speeds.
    init(topSpeed: Double = 330, grip: Double = 3.2) {
        // (length in metres, corner radius or nil for a straight, +1 left / -1 right)
        let segments: [(Double, Double?, Double)] = [
            (700, nil, 0), (90, 60, 1), (220, nil, 0), (140, 120, -1), (380, nil, 0),
            (80, 35, 1), (60, 35, 1), (300, nil, 0), (200, 200, -1), (520, nil, 0),
            (110, 45, -1), (250, nil, 0), (160, 90, 1), (90, 50, 1), (600, nil, 0),
            (140, 70, -1), (180, nil, 0), (130, 55, 1), (150, 110, -1), (390, nil, 0)
        ]
        var raw: [(x: Double, z: Double, k: Double)] = []
        var x = 0.0, z = 0.0, heading = 0.0
        for (segmentLength, radius, sign) in segments {
            for _ in 0..<Int(segmentLength) {
                let k = radius.map { sign / $0 } ?? 0
                heading += k
                x += cos(heading); z += sin(heading)
                raw.append((x, z, k))
            }
        }
        let n = raw.count
        // Spread the closing error along the lap so the circuit joins up.
        let closed = raw.enumerated().map { i, p in
            (x: p.x - x * Double(i) / Double(n), z: p.z - z * Double(i) / Double(n), k: p.k)
        }
        var target = closed.map { $0.k == 0 ? topSpeed : min(topSpeed, 3.6 * (grip * 9.81 / abs($0.k)).squareRoot()) }
        for i in stride(from: n - 2, through: 0, by: -1) { target[i] = min(target[i], target[i + 1] + 0.55) }
        for i in 1..<n { target[i] = min(target[i], target[i - 1] + 0.22) }

        points = (0..<n).map { i in
            let next = closed[(i + 1) % n]
            return Point(x: closed[i].x, z: closed[i].z,
                         yaw: atan2(next.z - closed[i].z, next.x - closed[i].x),
                         curvature: closed[i].k, targetSpeed: target[i])
        }
        length = Double(n)
    }

    func at(_ distance: Double) -> Point {
        points[Int(distance) % points.count]
    }
}
