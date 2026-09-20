import Foundation

/// Names for the goblins (made from the goblin's own seed, so a goblin keeps its name) and ideas for the princess.
enum Names {
    // Sounds goblins make, used for names like 咕嚕, 嘎啾 or 噗嘟牙.
    private static let sounds = ["咕", "嚕", "嘎", "啾", "噗", "嘟", "嘰", "嘿", "呱", "叭", "嗚", "嘻", "嘶", "啪", "咚", "噠", "嚓", "嗒", "咯", "哈",
                                 "嘭", "嗶", "吼", "嗡", "咻", "咔", "嚷", "嘖"]
    private static let endings = ["牙", "耳", "鼻", "腳", "爪", "角", "尾", "肚", "眼", "毛", "骨", "皮"]
    // Looks: 歪鼻, 臭腳, 老禿頭 …
    private static let looks = ["歪", "扁", "尖", "圓", "胖", "瘦", "禿", "臭", "醜", "髒", "黏", "皺", "麻", "斑", "刺", "彎", "缺", "破", "腫", "長"]
    private static let parts = ["牙", "耳", "鼻", "腳", "爪", "角", "尾", "肚", "眼", "毛", "骨", "皮", "舌", "膝", "指", "頭"]
    private static let honorifics = ["", "小", "老", "大", "阿"]
    // Things from the mud and the woods: 泥巴, 石頭, 蘑菇頭 …
    private static let stuff = ["泥", "石", "苔", "蘑", "蟲", "蛙", "蝸", "鏽", "灰", "煙", "炭", "骨", "菇", "蕈", "根", "藤", "沼", "霧", "渣", "焦", "苔", "菌", "刺", "蜂"]
    private static let stuffEndings = ["巴", "頭", "仔", "蛋", "包", "球", "塊", "渣", "團", "角"]

    /// How many different names the generator can make (with the patterns below): well over ten thousand.
    static var combinationCount: Int {
        let twoSounds = sounds.count * sounds.count * (1 + endings.count)
        let threeSounds = sounds.count * sounds.count * sounds.count
        let looksNames = honorifics.count * looks.count * parts.count
        let stuffNames = honorifics.count * stuff.count * stuffEndings.count
        return twoSounds + threeSounds + looksNames + stuffNames
    }

    /// A well-mixed number from a seed (splitmix64), so neighbouring seeds do not give neighbouring names.
    private static func mix(_ x: UInt64) -> UInt64 {
        var z = x &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// The name for a seed. The same seed always gives the same name, so a goblin keeps its name across restarts.
    static func goblin(seed: UInt64) -> String {
        var h = mix(seed)
        func pick(_ list: [String]) -> String {
            let item = list[Int(h % UInt64(list.count))]
            h = mix(h)
            return item
        }
        let roll = Int(h % 100)
        h = mix(h)
        switch roll {
        case 0..<50: // two sounds, sometimes with an ending: 咕嚕, 噗嘟牙
            let name = pick(sounds) + pick(sounds)
            return h % 4 == 0 ? name + pick(endings) : name
        case 50..<65: // three sounds: 咕嚕嘎
            return pick(sounds) + pick(sounds) + pick(sounds)
        case 65..<85: // a look: 歪鼻, 小禿頭
            return pick(honorifics) + pick(looks) + pick(parts)
        default: // something from the mud: 泥巴, 老蘑菇頭
            return pick(honorifics) + pick(stuff) + pick(stuffEndings)
        }
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
