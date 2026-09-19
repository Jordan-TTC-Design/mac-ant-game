import CoreGraphics
import Foundation

/// One wandering ant. Position is in global screen coordinates; heading in radians (0 = +x).
struct Ant {
    var pos: CGPoint
    var heading: Double
    var speed: Double
    var pause: Double = 0
    var legPhase: Double = Double.random(in: 0...(2 * .pi))

    init(at pos: CGPoint) {
        self.pos = pos
        heading = Double.random(in: 0..<(2 * .pi))
        speed = Double.random(in: 15...40)
    }

    var isMoving: Bool { pause <= 0 }

    mutating func update(dt: Double, walkable: [CGRect]) {
        if pause > 0 {
            pause -= dt
            return
        }
        // Occasionally stop for a moment, otherwise wander with a small random turn each frame.
        if Double.random(in: 0..<1) < 0.15 * dt {
            pause = Double.random(in: 0.3...1.5)
            return
        }
        heading += Double.random(in: -1...1) * 3.0 * dt

        let step = speed * dt
        let next = CGPoint(x: pos.x + cos(heading) * step, y: pos.y + sin(heading) * step)
        if walkable.contains(where: { $0.insetBy(dx: 4, dy: 4).contains(next) }) {
            pos = next
            legPhase += speed * dt * 0.9
        } else {
            heading += .pi + Double.random(in: -0.6...0.6) // bounce off the screen edge
        }
    }
}
