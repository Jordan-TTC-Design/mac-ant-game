import Foundation

/// The app used to be called AntFarm (bundle id dev.goblincamp.antfarm). On the first launch as GoblinCamp this
/// copies the old saved progress, nest picture and menu settings across, so nothing is lost. The old data is
/// left where it was, in case anything needs to go back.
enum Migration {
    private static let oldBundleID = "dev.goblincamp.antfarm"
    private static let oldFolderName = "AntFarm"
    private static let newFolderName = "GoblinCamp"
    private static let settingKeys = ["spawnInterval", "saveProgress", "nestImageWidth"]

    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "migratedFromAntFarm") == nil else { return }
        defaults.set(true, forKey: "migratedFromAntFarm")
        copyFiles()
        copySettings(into: defaults)
    }

    /// Copies everything in the old Application Support folder that the new one does not have yet.
    private static func copyFiles() {
        let fileManager = FileManager.default
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let old = support.appendingPathComponent(oldFolderName), new = support.appendingPathComponent(newFolderName)
        guard let names = try? fileManager.contentsOfDirectory(atPath: old.path), !names.isEmpty else { return }
        try? fileManager.createDirectory(at: new, withIntermediateDirectories: true)
        for name in names where !fileManager.fileExists(atPath: new.appendingPathComponent(name).path) {
            do {
                try fileManager.copyItem(at: old.appendingPathComponent(name), to: new.appendingPathComponent(name))
                NSLog("GoblinCamp: copied \(name) from the old \(oldFolderName) folder")
            } catch {
                NSLog("GoblinCamp: could not copy \(name): \(error)")
            }
        }
    }

    private static func copySettings(into defaults: UserDefaults) {
        guard let old = defaults.persistentDomain(forName: oldBundleID) else { return }
        for key in settingKeys where defaults.object(forKey: key) == nil {
            if let value = old[key] {
                defaults.set(value, forKey: key)
                NSLog("GoblinCamp: copied setting \(key) from the old \(oldFolderName)")
            }
        }
    }
}
