import Foundation

/// Names for the goblins (made from the goblin's own seed, so a goblin keeps its name) and ideas for the princess.
enum Names {
    // Names are plain names. Epithets and titles (疾風、勇者…) are kept for the future 稱號 (title) system, not part of the name.

    // Sounds goblins make: 咕嚕, 噗嘟牙 …
    private static let sounds = ["咕", "嚕", "嘎", "啾", "噗", "嘟", "嘰", "嘿", "呱", "叭", "嗚", "嘻", "嘶", "啪", "咚", "噠", "嚓", "嗒", "咯", "哈",
                                 "嘭", "嗶", "吼", "嗡", "咻", "咔", "嚷", "嘖"]
    private static let endings = ["牙", "耳", "鼻", "腳", "爪", "角", "尾", "肚", "眼", "毛", "骨", "皮"]
    // Cartoon-style syllables (the kind that spell 波波, 米露, 卡布奇 in Chinese cartoons and anime).
    private static let kana = ["波", "皮", "卡", "米", "咪", "布", "比", "潘", "妮", "莉", "露", "琪", "蒂", "迪", "奇", "基", "克", "庫", "姆", "尼",
                               "諾", "洛", "托", "塔", "達", "特", "娜", "拉", "蘭", "里", "利", "曼", "梅", "蜜", "摩", "莫", "歐", "帕", "派", "芬",
                               "佩", "菲", "弗", "赫", "伊", "傑", "凱", "科", "朗", "雷", "索", "提", "烏", "維", "沃", "希", "西", "澤", "茲", "貝",
                               "芭", "芙", "薇", "蕾", "艾", "亞", "雅", "奧", "可", "嘉", "咖", "圖", "多", "朵", "妲", "蕊", "娃", "溫", "威", "瓦",
                               "芝", "吉", "姬", "奈", "豆", "果", "栗", "桃", "棗", "芋", "綠", "苔"]
    private static let cuteSuffixes = ["醬", "君", "丸", "助", "太", "兒", "仔", "寶", "球", "糖", "豆", "泡", "丁", "喵"]
    private static let honorifics = ["小", "老", "大", "阿", "嘟"]
    // Looks and things from the mud: 歪鼻, 小禿頭, 泥巴, 蘑菇頭 …
    private static let looks = ["歪", "扁", "尖", "圓", "胖", "瘦", "禿", "臭", "醜", "髒", "黏", "皺", "麻", "斑", "刺", "彎", "缺", "破", "腫", "長"]
    private static let parts = ["牙", "耳", "鼻", "腳", "爪", "角", "尾", "肚", "眼", "毛", "骨", "皮", "舌", "膝", "指", "頭"]
    private static let stuff = ["泥", "石", "苔", "蘑", "蟲", "蛙", "蝸", "鏽", "灰", "煙", "炭", "骨", "菇", "蕈", "根", "藤", "沼", "霧", "渣", "焦", "菌", "刺", "蜂", "霜"]
    private static let stuffEndings = ["巴", "頭", "仔", "蛋", "包", "球", "塊", "渣", "團", "角"]

    /// How many different names the generator can make: over a million.
    static var combinationCount: Int {
        let s = sounds.count, k = kana.count, x = cuteSuffixes.count, h = honorifics.count
        return s * s * (1 + endings.count)            // 咕嚕, 噗嘟牙
            + k * k * k                                // 波米露
            + k * k * x                                // 米露醬
            + 2 * s * k * (1 + x)                      // 咕米, 波嘟丸
            + h * k * k                                // 小米露
            + k * (1 + x)                              // 波波, 米米醬
            + h * looks.count * parts.count            // 老禿頭
            + h * stuff.count * stuffEndings.count     // 阿蘑菇頭
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
        func maybe(_ list: [String], oneIn n: UInt64 = 2) -> String {
            let take = h % n == 0
            h = mix(h)
            return take ? pick(list) : ""
        }
        let roll = Int(h % 100)
        h = mix(h)
        switch roll {
        case 0..<15: // 咕嚕, 噗嘟牙
            let name = pick(sounds) + pick(sounds)
            return h % 4 == 0 ? name + pick(endings) : name
        case 15..<40: // 波米露
            return pick(kana) + pick(kana) + pick(kana)
        case 40..<60: // 米露醬
            return pick(kana) + pick(kana) + pick(cuteSuffixes)
        case 60..<70: // 咕米, 波嘟丸
            let mixed = h % 2 == 0 ? pick(sounds) + pick(kana) : pick(kana) + pick(sounds)
            return mixed + maybe(cuteSuffixes)
        case 70..<80: // 小米露
            return pick(honorifics) + pick(kana) + pick(kana)
        case 80..<90: // 波波, 米米醬
            let k = pick(kana)
            return k + k + maybe(cuteSuffixes)
        case 90..<95: // 老禿頭
            return pick(honorifics) + pick(looks) + pick(parts)
        default: // 阿蘑菇頭
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
