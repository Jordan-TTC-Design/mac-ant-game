import AppKit

/// One growth stage of a camp: a picture, where its entrance is, and how many goblins it takes to reach it.
struct CampStage {
    let image: CGImage
    /// The entrance in art pixels, measured from the top-left of the picture. It sits on the camp's spot on screen.
    let entrance: CGPoint
    let minCount: Int
}

/// A look for the camp, in a few growth stages (a folder with `manifest.json` and one PNG per stage).
final class CampStyle {
    let id: String
    let name: String
    let blurb: String
    /// Points per art pixel.
    let pixelScale: Double
    let stages: [CampStage]

    init(id: String, name: String, blurb: String, pixelScale: Double, stages: [CampStage]) {
        self.id = id
        self.name = name
        self.blurb = blurb
        self.pixelScale = pixelScale
        self.stages = stages
    }

    /// The biggest stage the camp has grown into.
    func stage(forCount count: Int) -> CampStage {
        stages.last { $0.minCount <= count } ?? stages[0]
    }
}

enum Camps {
    /// `campID` of the player's own picture (see `NestImageStore`).
    static let customID = "custom"

    static let all: [CampStyle] = loadFolders()

    static func style(id: String) -> CampStyle? { all.first { $0.id == id } }

    /// The look in use, or nil when the player's own picture is chosen.
    static var current: CampStyle? {
        let id = Settings.shared.campID
        if id == customID { return nil }
        return style(id: id) ?? all.first
    }

    // MARK: Loading

    private struct Manifest: Decodable {
        struct Stage: Decodable {
            let sheet: String
            let minCount: Int
            let entrance: [Double]
        }
        let id: String
        let name: String
        let blurb: String?
        let pixelScale: Double
        let stages: [Stage]
    }

    private static var searchFolders: [URL] {
        var folders: [URL] = []
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("Camps") { folders.append(bundled) }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folders.append(support.appendingPathComponent("GoblinCamp/Camps"))
        return folders
    }

    private static func loadFolders() -> [CampStyle] {
        var result: [CampStyle] = []
        for root in searchFolders {
            let entries = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            for folder in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard let style = load(folder: folder), !result.contains(where: { $0.id == style.id }) else { continue }
                result.append(style)
            }
        }
        // the built-in order (mound, cave, stump, tent) reads better than alphabetical
        let preferred = ["mound", "cave", "stump", "tent"]
        return result.sorted { (preferred.firstIndex(of: $0.id) ?? 99) < (preferred.firstIndex(of: $1.id) ?? 99) }
    }

    private static func load(folder: URL) -> CampStyle? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("manifest.json")) else { return nil }
        do {
            let manifest = try JSONDecoder().decode(Manifest.self, from: data)
            let stages: [CampStage] = manifest.stages.compactMap { stage in
                guard let source = CGImageSourceCreateWithURL(folder.appendingPathComponent(stage.sheet) as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil), stage.entrance.count == 2 else { return nil }
                return CampStage(image: image, entrance: CGPoint(x: stage.entrance[0], y: stage.entrance[1]), minCount: stage.minCount)
            }.sorted { $0.minCount < $1.minCount }
            guard !stages.isEmpty else { return nil }
            return CampStyle(id: manifest.id, name: manifest.name, blurb: manifest.blurb ?? "", pixelScale: manifest.pixelScale, stages: stages)
        } catch {
            NSLog("GoblinCamp: could not load camp in \(folder.lastPathComponent): \(error)")
            return nil
        }
    }
}
