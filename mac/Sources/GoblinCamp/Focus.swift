import Foundation

/// The pomodoro's focus rounds as the camp's books keep them (shared/src/camp/focus.ts): the server counts every focus part
/// that runs to its end (a skipped one does not count), from this Mac or the phone. A day with more of them is a better day
/// at the camp: the merchant comes once more (Merchant.swift), the ranch breeds faster (Ranch.swift), and the merchant
/// brings a rare find (the server puts it in the visit's stock).
struct FocusInfo: Codable, Equatable {
    struct Day: Codable, Equatable { let rounds: Int; let minutes: Int }
    struct Perks: Codable, Equatable { let merchant: Bool; let ranch: Bool; let rare: Bool }
    struct Next: Codable, Equatable { let perk: String; let rounds: Int }
    let today: Day
    let rounds: Int
    let minutes: Int
    let bestDay: Int
    let perks: Perks
    let next: Next?

    /// Rounds in a day for each good thing (shared/src/camp/focus.ts).
    static let merchantRounds = 3, ranchRounds = 4, rareRounds = 6
    /// How much faster the ranch breeds on such a day.
    static let ranchSpeed = 1.5

    /// What the camp says when a round is done: what it brought, or how far the next good thing is (focusLine).
    static func line(rounds: Int) -> String {
        switch rounds {
        case merchantRounds: return "今天專注第 \(rounds) 輪！商人聽說了，等一下會來一趟。"
        case ranchRounds: return "今天專注第 \(rounds) 輪！牧場今天生得比較快。"
        case rareRounds: return "今天專注第 \(rounds) 輪！商人今天會帶稀有的東西來。"
        default:
            if let next = [merchantRounds, ranchRounds, rareRounds].first(where: { $0 > rounds }) { return "今天專注第 \(rounds) 輪，再 \(next - rounds) 輪營地有好事。" }
            return "今天專注第 \(rounds) 輪，辛苦了！"
        }
    }
}
