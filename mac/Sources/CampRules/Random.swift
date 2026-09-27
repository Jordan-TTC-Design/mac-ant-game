/// Seeded randomness, bit for bit the same as shared/src/world/random.ts (FNV-1a with a final mix, and mulberry32), so a
/// Mac works out the same residents as the server.
public enum CampRandom {
    /// A 32-bit hash of a string, over its UTF-16 code units (as JavaScript's `charCodeAt`).
    public static func hash(_ text: String) -> UInt32 {
        var h: UInt32 = 0x811c9dc5
        for unit in text.utf16 {
            h ^= UInt32(unit)
            h = h &* 0x01000193
        }
        h ^= h >> 16
        h = h &* 0x85ebca6b
        h ^= h >> 13
        h = h &* 0xc2b2ae35
        h ^= h >> 16
        return h
    }

    /// A generator of numbers in [0, 1) (mulberry32).
    public struct Generator {
        private var a: UInt32
        public init(seed: UInt32) { a = seed }
        public mutating func next() -> Double {
            a = a &+ 0x6d2b79f5
            var t = a
            t = (t ^ (t >> 15)) &* (t | 1)
            t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
            return Double(t ^ (t >> 14)) / 4294967296
        }
    }

    /// A generator seeded from several parts joined by "|" (whole numbers written plainly, as JavaScript does).
    public static func seeded(_ parts: [String]) -> Generator { Generator(seed: hash(parts.joined(separator: "|"))) }

    /// One item, picked with the given weights (the same arithmetic as `pickWeighted`).
    public static func pickWeighted<T>(_ random: inout Generator, _ items: [T], weight: (T) -> Double) -> T {
        let total = items.reduce(0.0) { $0 + max(0, weight($1)) }
        var roll = random.next() * total
        for item in items {
            roll -= max(0, weight(item))
            if roll < 0 { return item }
        }
        return items[items.count - 1]
    }
}
