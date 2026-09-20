import AppKit

/// Watches what a frame costs (the simulation plus drawing the camp) and, when it gets too heavy, lets fewer goblins walk about at once
/// (the rest wait in the nest, which costs almost nothing). When the load eases it lets them out again, slowly. It only measures
/// while the camp is on the screen.
final class PerfGovernor {
    static let shared = PerfGovernor()

    /// How many milliseconds a frame may take, on average, before goblins are held back. `CAMP_PERF_BUDGET` overrides it (tests).
    static let budget = Double(ProcessInfo.processInfo.environment["CAMP_PERF_BUDGET"] ?? "") ?? 12

    /// 1 = everybody may be out; smaller = that share of the usual number. Never below 0.3.
    private(set) var scale = 1.0
    /// The average cost of a frame in the last check, in milliseconds.
    private(set) var lastMilliseconds = 0.0
    var enabled = true

    private var drawTime = 0.0, tickTime = 0.0, frames = 0
    private var windowStart = CACurrentMediaTime()
    private static let window = 3.0

    /// What the goblins are allowed to use: `scale`, or 1 when the guard is off.
    var factor: Double { enabled ? scale : 1 }
    /// Drawing the little extras (worn gear, effects) is dropped when the load is high.
    var showsDetail: Bool { factor >= 0.6 }

    func recordDraw(_ seconds: Double) { drawTime += seconds }
    func recordTick(_ seconds: Double) { tickTime += seconds }

    /// Call once per simulated frame.
    func frameDone() {
        frames += 1
        let now = CACurrentMediaTime()
        guard now - windowStart >= PerfGovernor.window else { return }
        lastMilliseconds = (drawTime + tickTime) / Double(max(1, frames)) * 1000
        if lastMilliseconds > PerfGovernor.budget {
            scale = max(0.3, scale * 0.8)
        } else if lastMilliseconds < PerfGovernor.budget * 0.45 {
            scale = min(1, scale * 1.1)
        }
        drawTime = 0
        tickTime = 0
        frames = 0
        windowStart = now
    }

    /// Nothing to measure for a while (the camp was hidden): start over.
    func reset() {
        drawTime = 0
        tickTime = 0
        frames = 0
        windowStart = CACurrentMediaTime()
    }
}
