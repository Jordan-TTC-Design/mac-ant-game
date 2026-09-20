import AppKit
import AVFoundation

/// Why something wants the player: Claude needs a decision, or Claude is done.
enum NotifyKind: String {
    case permission, done
}

/// What sound comes before the words.
enum Sfx: String, CaseIterable {
    case giggle, squeak, grunt, hum, chime, sparkle
}

/// Who is talking: the princess, or a goblin of one breed. Each has its own voice, tone and things to say.
struct Speaker {
    let id: String
    let name: String
    /// What the bubble calls the speaker (a goblin's own name can go here later).
    let title: String
    /// Names of the macOS voices to prefer (first match wins), all Traditional Chinese.
    let voiceHints: [String]
    /// 0.5–2.0; higher is squeakier.
    let pitch: Float
    /// 0–1, 0.5 is normal speed.
    let rate: Float
    let sfx: Sfx
    let permission: [String]
    let done: [String]
    var isPrincess: Bool { id == "princess" }

    func line(for kind: NotifyKind) -> String {
        (kind == .permission ? permission : done).randomElement() ?? "嘻嘻！"
    }
}

enum Speakers {
    static let princess = Speaker(
        id: "princess", name: "公主", title: "公主", voiceHints: ["Meijia", "Sandy", "Flo"], pitch: 1.12, rate: 0.48, sfx: .chime,
        permission: ["那個…Claude 在等你確認喔。", "打擾一下～需要你點個頭呢。", "請你來看一下，它不知道能不能做喔。"],
        done: ["工作完成囉，辛苦了！", "Claude 做好了喔，快來看看～", "都弄好了，你可以休息一下下。"])

    static let common = Speaker(
        id: "common", name: "平民", title: "哥布林", voiceHints: ["Eddy", "Reed", "Rocko"], pitch: 2.0, rate: 0.56, sfx: .giggle,
        permission: ["老大老大！有人在等你點頭啦，嘻嘻！", "嘰嘰！有東西要你批准！快來快來！", "嘿嘿，人類問你可不可以做這個！"],
        done: ["搞定啦搞定啦！嘻嘻嘻！", "工作做完了，快來看快來看！", "嘿嘿，全部弄好啦！"])

    static let scout = Speaker(
        id: "scout", name: "敏捷", title: "敏捷哥布林", voiceHints: ["Flo", "Sandy", "Eddy"], pitch: 2.0, rate: 0.72, sfx: .squeak,
        permission: ["報告！有人在等你！快！", "急報急報！要你決定！", "快來快來快來！"],
        done: ["好了好了！跑完啦！", "報告！任務完成！", "搞定！下一個！"])

    static let brute = Speaker(
        id: "brute", name: "壯碩", title: "壯碩哥布林", voiceHints: ["Grandpa", "Reed", "Rocko"], pitch: 0.55, rate: 0.38, sfx: .grunt,
        permission: ["嗯。要你點頭。", "喂。你，過來。它在等。", "哼。需要你決定。"],
        done: ["完成。哼。", "做完了。很簡單。", "好了。可以吃東西了嗎。"])

    static let sage = Speaker(
        id: "sage", name: "聰明", title: "聰明哥布林", voiceHints: ["Grandma", "Shelley", "Sandy"], pitch: 1.35, rate: 0.44, sfx: .hum,
        permission: ["嗯哼，需要您的許可，請過目。", "根據我的觀察，現在需要您做決定。", "容我提醒，有一件事等您批准。"],
        done: ["根據我的推算，工作已經完成。", "嗯哼，一切都在計畫之中，完成了。", "報告，成果已經備妥。"])

    static let golden = Speaker(
        id: "golden", name: "金皮", title: "金皮哥布林", voiceHints: ["Shelley", "Flo", "Sandy"], pitch: 1.7, rate: 0.5, sfx: .sparkle,
        permission: ["本金皮大人通知你，快來批准！", "哦呵呵，有事要你決定，還不快來！"],
        done: ["哦呵呵，辦妥了，賞我點吃的吧！", "本大人親自完成的，快誇獎我！"])

    static func forBreed(_ id: String) -> Speaker {
        switch id {
        case "scout": return scout
        case "brute": return brute
        case "sage": return sage
        case "golden": return golden
        default: return common
        }
    }
}

/// One popup: someone walks in from the edge of a screen, says their piece in a bubble, and walks off again.
/// What a popup lets the player do besides reading it.
enum Interaction {
    /// Claude wants permission: allow, deny or go and look.
    case decision
    /// Claude is done: type a reply, or go and look.
    case reply
}

struct Message {
    enum Phase { case walkingIn, talking, leaving }

    let kind: NotifyKind
    let speaker: Speaker
    /// Which breed's sprite to use (ignored for the princess).
    let breedIndex: Int
    let text: String
    /// Who exactly is talking (a goblin's own name, or the princess's); empty falls back to the kind of goblin.
    var name = ""
    /// A note without sound (the summary when coming back).
    let silent: Bool
    /// The project (folder) the Claude session works in, if the hook told us.
    let project: String
    /// Bundle id of the app Claude runs in (Terminal, iTerm, VS Code…); clicking the popup brings it forward.
    let appBundleID: String?
    /// Set for popups the player can answer; `askID` names the reply file the waiting hook is polling.
    let interaction: Interaction?
    let askID: String?
    /// A short line under the words (what Claude wants to run).
    let context: String
    /// What "allow and remember" would let through for the rest of this conversation (empty: no such button).
    var remember = ""
    /// The line under the words: what Claude wants to do, and what "remember" would allow.
    var displayContext: String { remember.isEmpty ? context : (context.isEmpty ? "" : context + "\n") + "本次對話都允許：" + remember }
    let screen: CGRect
    var pos: CGPoint
    var phase: Phase = .walkingIn
    var timer = 0.0
    var walked = 0.0
    let stopX: CGFloat
    let talkTime: Double

    init(kind: NotifyKind, speaker: Speaker, breedIndex: Int, project: String, appBundleID: String?, screen: CGRect, text custom: String? = nil, silent: Bool = false,
         interaction: Interaction? = nil, askID: String? = nil, context: String = "", talkTime custom_talk: Double? = nil) {
        self.silent = silent
        self.interaction = interaction
        self.askID = askID
        self.context = context
        self.kind = kind
        self.appBundleID = appBundleID
        self.speaker = speaker
        self.breedIndex = breedIndex
        self.project = project
        self.screen = screen
        text = custom ?? speaker.line(for: kind)
        pos = CGPoint(x: screen.maxX + 40, y: screen.maxY - 230) // top right, under the menu bar, with room for the bubble above
        stopX = screen.maxX - 190
        talkTime = custom_talk ?? max(4.5, Double(text.count) * 0.3)
    }

    var heading: Double { phase == .leaving ? 0 : .pi }

    /// The heading of the bubble: "咕嚕・壯碩哥布林" or "艾莉雅・公主".
    var title: String { name.isEmpty ? speaker.title : "\(name)・\(speaker.isPrincess ? "公主" : speaker.title)" }

    var accent: NSColor {
        kind == .permission ? NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.1, alpha: 1)
                            : NSColor(calibratedRed: 0.25, green: 0.65, blue: 0.3, alpha: 1)
    }

    /// The bubble's content: who is talking, what they say, and where (project) and what a click does.
    var attributed: NSAttributedString {
        let full = NSMutableAttributedString()
        full.append(NSAttributedString(string: "\(title)\n", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: accent]))
        full.append(NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold), .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1)]))
        var footer: [String] = []
        if !project.isEmpty { footer.append("專案：\(project)") }
        if appBundleID != nil { footer.append("點一下回到 Claude") }
        if !footer.isEmpty {
            full.append(NSAttributedString(string: "\n" + footer.joined(separator: "　·　"), attributes: [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .regular), .foregroundColor: NSColor(calibratedWhite: 0.45, alpha: 1)]))
        }
        return full
    }

    static let bubblePadding: CGFloat = 10

    var bubbleTextSize: NSSize {
        let box = attributed.boundingRect(with: NSSize(width: 230, height: 400), options: [.usesLineFragmentOrigin])
        return NSSize(width: ceil(box.width) + 2, height: ceil(box.height))
    }

    /// Where the bubble sits (global coordinates) above a speaker whose head top is at `head`.
    func bubbleRect(headTop head: CGPoint) -> NSRect {
        let size = bubbleTextSize, pad = Message.bubblePadding
        return NSRect(x: head.x - size.width - pad * 2 + 30, y: head.y + 12, width: size.width + pad * 2, height: size.height + pad * 2)
    }

    /// The area that answers to a click: the bubble and the speaker under it.
    func hitRect(spriteSize: CGFloat) -> NSRect {
        let bubble = bubbleRect(headTop: CGPoint(x: pos.x, y: pos.y + spriteSize * 0.8))
        let body = NSRect(x: pos.x - spriteSize / 2, y: pos.y - 6, width: spriteSize, height: spriteSize)
        return bubble.union(body)
    }

    /// Ends the talk early (someone clicked it).
    mutating func dismiss() { if phase != .leaving { phase = .leaving } }
}

/// The queue of popups; only one is on screen at a time.
final class MessageStage {
    private(set) var current: Message?
    private var queue: [Message] = []
    /// Called when the messenger arrives and starts talking (the sound plays then).
    var onArrive: ((Message) -> Void)?

    static let walkSpeed = 190.0
    static let maxQueued = 3

    var isActive: Bool { current != nil }
    var isFull: Bool { queue.count >= MessageStage.maxQueued }

    func enqueue(_ message: Message) {
        guard queue.count < MessageStage.maxQueued else { return }
        queue.append(message)
        if current == nil { current = queue.removeFirst() }
    }

    func clear() {
        current = nil
        queue = []
    }

    /// The player clicked the popup: the messenger goes away.
    func dismissCurrent() { current?.dismiss() }

    /// Whether a popup for this question is still on screen or waiting its turn.
    func hasAsk(_ id: String) -> Bool {
        current?.askID == id || queue.contains { $0.askID == id }
    }

    /// The popup for this question is on its way out (nobody answered in time).
    func isLeaving(ask id: String) -> Bool {
        current?.askID == id && current?.phase == .leaving
    }

    func update(dt: Double) {
        guard var m = current else { return }
        switch m.phase {
        case .walkingIn:
            let step = MessageStage.walkSpeed * dt
            m.pos.x -= CGFloat(step)
            m.walked += step
            if m.pos.x <= m.stopX {
                m.pos.x = m.stopX
                m.phase = .talking
                m.timer = 0
                current = m
                onArrive?(m)
                return
            }
        case .talking:
            m.timer += dt
            if m.timer >= m.talkTime { m.phase = .leaving }
        case .leaving:
            let step = MessageStage.walkSpeed * dt
            m.pos.x += CGFloat(step)
            m.walked += step
            if m.pos.x > m.screen.maxX + 60 {
                current = queue.isEmpty ? nil : queue.removeFirst()
                return
            }
        }
        current = m
    }
}

// MARK: Sound

/// Tiny synthesizer for the little sounds that come before the words.
private struct Synth {
    static let rate = 22050.0
    var samples: [Float] = []

    mutating func silence(_ seconds: Double) {
        samples += [Float](repeating: 0, count: Int(seconds * Synth.rate))
    }

    /// A tone gliding from `f0` to `f1` Hz with a few harmonics, a wobble and a fading tail.
    mutating func tone(from f0: Double, to f1: Double, duration: Double, amp: Double = 0.5, wobble: Double = 0,
                       harmonics: [Double] = [1, 0.4, 0.15], decay: Double = 3) {
        let n = Int(duration * Synth.rate)
        var phase = 0.0
        let norm = harmonics.reduce(0, +)
        for i in 0..<n {
            let t = Double(i) / Synth.rate
            let f = f0 + (f1 - f0) * t / duration + wobble * f0 * sin(2 * .pi * 34 * t)
            phase += 2 * .pi * f / Synth.rate
            var v = 0.0
            for (k, h) in harmonics.enumerated() { v += h * sin(Double(k + 1) * phase) }
            let env = min(1, t / 0.006) * exp(-decay * t / duration) * min(1, (duration - t) / 0.01)
            samples.append(Float(v / norm * amp * env))
        }
    }

    /// 16-bit mono WAV.
    var wav: Data {
        var data = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); u32(36 + bytes)
        data.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16); u16(1); u16(1)
        u32(UInt32(Synth.rate)); u32(UInt32(Synth.rate) * 2); u16(2); u16(16)
        data.append(contentsOf: Array("data".utf8)); u32(bytes)
        for s in samples { u16(UInt16(bitPattern: Int16(max(-1, min(1, s)) * 32000))) }
        return data
    }

    static func make(_ sfx: Sfx) -> Synth {
        var s = Synth()
        switch sfx {
        case .giggle: // "hee-hee-hee-hee": short bursts, each a little higher
            for i in 0..<5 {
                s.tone(from: 880 + Double(i) * 60, to: 1150 + Double(i) * 70, duration: 0.075, amp: 0.5, wobble: 0.03)
                s.silence(0.05)
            }
        case .squeak: // two quick upward chirps
            s.tone(from: 1300, to: 2400, duration: 0.09, amp: 0.45, harmonics: [1, 0.25])
            s.silence(0.05)
            s.tone(from: 1500, to: 2700, duration: 0.09, amp: 0.45, harmonics: [1, 0.25])
        case .grunt: // low rumble twice
            for _ in 0..<2 {
                s.tone(from: 130, to: 80, duration: 0.24, amp: 0.7, wobble: 0.04, harmonics: [1, 0.8, 0.6, 0.4, 0.3], decay: 1.5)
                s.silence(0.08)
            }
        case .hum: // a thoughtful "hmm"
            s.tone(from: 210, to: 250, duration: 0.42, amp: 0.55, wobble: 0.015, harmonics: [1, 0.5, 0.2], decay: 1.2)
        case .chime: // two soft bell notes
            s.tone(from: 1046, to: 1046, duration: 0.35, amp: 0.4, harmonics: [1, 0.2], decay: 4)
            s.tone(from: 1318, to: 1318, duration: 0.45, amp: 0.4, harmonics: [1, 0.2], decay: 4)
        case .sparkle: // a little rising arpeggio and one giggle
            for f in [1568.0, 1976, 2349, 2637] {
                s.tone(from: f, to: f, duration: 0.09, amp: 0.35, harmonics: [1, 0.15], decay: 3)
            }
            s.silence(0.04)
            s.tone(from: 1000, to: 1300, duration: 0.09, amp: 0.45, wobble: 0.03)
        }
        return s
    }
}

/// Plays the sound and speaks the line. Volume 0 is silent.
final class GoblinVoice: NSObject {
    static let shared = GoblinVoice()

    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var cache: [Sfx: Data] = [:]
    private var pending: DispatchWorkItem?

    /// 0 = off, 1…3 = quiet, medium, loud.
    static func volume(level: Int) -> Float { [0, 0.35, 0.7, 1.0][min(max(level, 0), 3)] }

    func speak(_ text: String, as speaker: Speaker, level: Int) {
        let volume = GoblinVoice.volume(level: level)
        guard volume > 0 else { return }
        stop()
        // the little sound first, then the words
        var wait = 0.0
        let data = cache[speaker.sfx] ?? Synth.make(speaker.sfx).wav
        cache[speaker.sfx] = data
        if let player = try? AVAudioPlayer(data: data) {
            player.volume = volume
            player.play()
            self.player = player
            wait = player.duration * 0.85
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = GoblinVoice.voice(for: speaker)
            utterance.pitchMultiplier = speaker.pitch
            utterance.rate = speaker.rate
            utterance.volume = volume
            self.synthesizer.speak(utterance)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + wait, execute: work)
    }

    func stop() {
        pending?.cancel()
        pending = nil
        player?.stop()
        synthesizer.stopSpeaking(at: .immediate)
    }

    var isPlaying: Bool { (player?.isPlaying ?? false) || synthesizer.isSpeaking }

    private static func voice(for speaker: Speaker) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "zh-TW" }
        for hint in speaker.voiceHints {
            if let match = voices.first(where: { $0.name.localizedCaseInsensitiveContains(hint) }) { return match }
        }
        return voices.first ?? AVSpeechSynthesisVoice(language: "zh-TW")
    }
}
