import AppKit

/// A pomodoro timer with a goblin at the top right of the screen holding up an electronic clock:
/// focus time counts down, then a rest counts down, then the goblin walks away.
final class Pomodoro {
    enum Phase { case focus, rest }
    enum Event { case started, focusDone, restBegan, finished }

    private(set) var phase: Phase?
    private(set) var endsAt = Date()
    private(set) var pos = CGPoint.zero
    private(set) var walked = 0.0
    /// Seconds of clock-shaking left after a phase change.
    private(set) var shake = 0.0
    private(set) var breedIndex = 0
    private(set) var arriving = false
    private(set) var leaving = false
    /// The last run ended straight after the focus time, with no rest.
    private(set) var endedWithoutRest = false
    /// How long the focus part was.
    private(set) var focusSeconds = 0.0
    private var screen = CGRect.zero
    private var restSeconds = 0.0
    private var targetX: CGFloat = 0
    /// Total length of the current phase, for the progress bar.
    private(set) var phaseLength = 1.0
    var onEvent: ((Event) -> Void)?

    static let walkSpeed = 170.0

    var isRunning: Bool { phase != nil }
    var isVisible: Bool { phase != nil || leaving }
    var remaining: TimeInterval { max(0, endsAt.timeIntervalSinceNow) }

    /// The goblin stands under the menu bar, near the right edge.
    func start(focusMinutes: Double, restMinutes: Double, screen: CGRect, breedIndex: Int) {
        self.screen = screen
        self.breedIndex = breedIndex
        restSeconds = restMinutes * 60
        focusSeconds = focusMinutes * 60
        endedWithoutRest = false
        phaseLength = focusMinutes * 60
        endsAt = Date().addingTimeInterval(phaseLength)
        phase = .focus
        leaving = false
        shake = 0
        targetX = screen.maxX - 90
        // already standing there (restarted): stay; otherwise walk in from the edge
        if !(pos.x > 0 && abs(pos.x - targetX) < 1 && pos.y == screen.maxY - 150) {
            pos = CGPoint(x: screen.maxX + 40, y: screen.maxY - 150)
            arriving = true
        }
        onEvent?(.started)
    }

    func stop() {
        guard phase != nil else { return }
        phase = nil
        leaving = true
        arriving = false
    }

    func update(dt: Double) {
        if arriving {
            let step = Pomodoro.walkSpeed * dt
            pos.x -= CGFloat(step)
            walked += step
            if pos.x <= targetX { pos.x = targetX; arriving = false }
        }
        shake = max(0, shake - dt)
        if leaving {
            let step = Pomodoro.walkSpeed * dt
            pos.x += CGFloat(step)
            walked += step
            if pos.x > screen.maxX + 60 { leaving = false; pos = .zero }
            return
        }
        guard let phase, remaining <= 0 else { return }
        if phase == .focus { onEvent?(.focusDone) }
        if phase == .focus, restSeconds > 0 {
            self.phase = .rest
            phaseLength = restSeconds
            endsAt = Date().addingTimeInterval(restSeconds)
            shake = 3
            onEvent?(.restBegan)
        } else {
            endedWithoutRest = phase == .focus
            self.phase = nil
            leaving = true
            onEvent?(.finished)
        }
    }
}

extension Speakers {
    /// What a goblin says when the pomodoro changes; each kind of goblin in its own tone.
    static func pomodoroLine(_ speaker: Speaker, _ event: Pomodoro.Event) -> String {
        let lines: [String: [Pomodoro.Event: [String]]] = [
            "common": [.started: ["開工開工！嘻嘻！"], .restBegan: ["時間到啦！休息休息，嘻嘻嘻！"], .finished: ["休息完啦，繼續加油！嘿嘿！"]],
            "scout": [.started: ["出發！我幫你計時！"], .restBegan: ["時間到！快去休息！"], .finished: ["休息結束！衝啊！"]],
            "brute": [.started: ["嗯。開始。我看著你。"], .restBegan: ["時間到。休息。"], .finished: ["休息完了。去做事。"]],
            "sage": [.started: ["嗯哼，專注時間開始了。"], .restBegan: ["專注時間已滿，建議您起身活動。"], .finished: ["休息完畢，請繼續您的工作。"]],
            "golden": [.started: ["哦呵呵，本大人替你計時！"], .restBegan: ["時間到，本大人准你休息！"], .finished: ["休息夠了，繼續努力吧！"]],
        ]
        return lines[speaker.id]?[event]?.randomElement() ?? "時間到啦！"
    }
}
