import AppKit

/// A pomodoro timer with a goblin at the top right of the screen holding up an electronic clock: focus time counts down, then a
/// rest, and so on for as many rounds as chosen (the last round is followed by a long rest); then the goblin walks away.
/// It can be paused and a part can be skipped.
final class Pomodoro {
    enum Phase { case focus, rest, longRest }
    enum Event { case started, focusDone, restBegan, longRestBegan, focusBegan, finished }

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
    /// How long a focus part is.
    private(set) var focusSeconds = 0.0
    /// Which round it is (1-based) and how many there are.
    private(set) var round = 1
    private(set) var rounds = 1
    private(set) var paused = false
    private var pausedRemaining = 0.0
    private var screen = CGRect.zero
    private var restSeconds = 0.0
    private var longRestSeconds = 0.0
    private var targetX: CGFloat = 0
    /// Total length of the current phase, for the progress bar.
    private(set) var phaseLength = 1.0
    var onEvent: ((Event) -> Void)?

    static let walkSpeed = 170.0

    var isRunning: Bool { phase != nil }
    var isVisible: Bool { phase != nil || leaving }
    var isRest: Bool { phase == .rest || phase == .longRest }
    var remaining: TimeInterval { paused ? pausedRemaining : max(0, endsAt.timeIntervalSinceNow) }

    /// The goblin stands under the menu bar, near the right edge.
    func start(focusMinutes: Double, restMinutes: Double, rounds: Int = 1, longRestMinutes: Double = 0, screen: CGRect, breedIndex: Int) {
        self.screen = screen
        self.breedIndex = breedIndex
        restSeconds = restMinutes * 60
        longRestSeconds = longRestMinutes * 60
        focusSeconds = focusMinutes * 60
        self.rounds = max(1, rounds)
        round = 1
        paused = false
        endedWithoutRest = false
        begin(.focus, seconds: focusSeconds)
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

    private func begin(_ next: Phase, seconds: Double) {
        phase = next
        phaseLength = max(1, seconds)
        endsAt = Date().addingTimeInterval(seconds)
        paused = false
    }

    func stop() {
        guard phase != nil else { return }
        phase = nil
        paused = false
        leaving = true
        arriving = false
    }

    func pause() {
        guard phase != nil, !paused else { return }
        pausedRemaining = remaining
        paused = true
    }

    func resume() {
        guard phase != nil, paused else { return }
        endsAt = Date().addingTimeInterval(pausedRemaining)
        paused = false
    }

    /// Ends the current part right now and goes on to the next.
    func skip() {
        guard phase != nil else { return }
        if paused { pausedRemaining = 0 } else { endsAt = Date() }
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
        switch phase {
        case .focus:
            onEvent?(.focusDone)
            if round < rounds {
                if restSeconds > 0 { begin(.rest, seconds: restSeconds); shake = 3; onEvent?(.restBegan) } else { nextRound() }
            } else if rounds > 1, longRestSeconds > 0 {
                begin(.longRest, seconds: longRestSeconds)
                shake = 3
                onEvent?(.longRestBegan)
            } else if restSeconds > 0 {
                begin(.rest, seconds: restSeconds)
                shake = 3
                onEvent?(.restBegan)
            } else {
                finish(withoutRest: true)
            }
        case .rest:
            if round < rounds { nextRound() } else { finish(withoutRest: false) }
        case .longRest:
            finish(withoutRest: false)
        }
    }

    private func nextRound() {
        round += 1
        begin(.focus, seconds: focusSeconds)
        shake = 3
        onEvent?(.focusBegan)
    }

    private func finish(withoutRest: Bool) {
        endedWithoutRest = withoutRest
        phase = nil
        paused = false
        leaving = true
        onEvent?(.finished)
    }
}

extension Speakers {
    /// What a goblin says when the pomodoro changes; each kind of goblin in its own tone.
    static func pomodoroLine(_ speaker: Speaker, _ event: Pomodoro.Event) -> String {
        let lines: [String: [Pomodoro.Event: [String]]] = [
            "common": [.started: ["開工開工！嘻嘻！"], .restBegan: ["時間到啦！休息休息，嘻嘻嘻！"], .finished: ["休息完啦，繼續加油！嘿嘿！"], .focusBegan: ["下一輪開始啦！嘿嘿！"], .longRestBegan: ["全部做完啦！長長的休息，嘻嘻！"]],
            "scout": [.started: ["出發！我幫你計時！"], .restBegan: ["時間到！快去休息！"], .finished: ["休息結束！衝啊！"], .focusBegan: ["下一輪！衝衝衝！"], .longRestBegan: ["全部跑完啦！大休息！"]],
            "brute": [.started: ["嗯。開始。我看著你。"], .restBegan: ["時間到。休息。"], .finished: ["休息完了。去做事。"], .focusBegan: ["下一輪。開始。"], .longRestBegan: ["都做完了。好好休息。"]],
            "sage": [.started: ["嗯哼，專注時間開始了。"], .restBegan: ["專注時間已滿，建議您起身活動。"], .finished: ["休息完畢，請繼續您的工作。"], .focusBegan: ["下一輪專注時間開始。"], .longRestBegan: ["整組完成，請安心地長休息。"]],
            "golden": [.started: ["哦呵呵，本大人替你計時！"], .restBegan: ["時間到，本大人准你休息！"], .finished: ["休息夠了，繼續努力吧！"], .focusBegan: ["下一輪，本大人繼續替你計時！"], .longRestBegan: ["全部完成，本大人准你長休息！"]],
        ]
        return lines[speaker.id]?[event]?.randomElement() ?? "時間到啦！"
    }
}
