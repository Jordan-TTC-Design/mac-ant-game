import Foundation

/// Names for the goblins (made from the goblin's own seed, so a goblin keeps its name) and ideas for the princess.
enum Names {
    private static let syllables = ["咕", "嚕", "嘎", "啾", "噗", "嘟", "嘰", "嘿", "呱", "叭", "嗚", "嘻", "扁", "豆", "歪", "尖"]
    private static let suffixes = ["", "", "", "", "", "", "牙", "耳", "鼻", "腳"]

    /// Something like 咕嚕, 嘎啾 or 噗嘟牙: two syllables and now and then a small ending.
    static func goblin(seed: UInt64) -> String {
        let n = syllables.count
        let a = Int(seed % UInt64(n))
        let b = Int((seed / UInt64(n)) % UInt64(n))
        let c = Int((seed / UInt64(n * n)) % UInt64(suffixes.count))
        return syllables[a] + syllables[b] + suffixes[c]
    }

    static let princessIdeas = ["艾莉雅", "小茉", "露米", "米娜", "莉娜", "蘇菲", "小晴", "梅兒", "希兒", "可可", "薇薇", "小雪", "安妮", "伊芙", "琪琪"]

    static func randomPrincess(except current: String = "") -> String {
        princessIdeas.filter { $0 != current }.randomElement() ?? "公主"
    }

    /// A name typed by the player: trimmed, one line, not too long. Empty means "no name".
    static func clean(_ text: String, limit: Int = 8) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).filter { !$0.isNewline }.prefix(limit))
    }
}
