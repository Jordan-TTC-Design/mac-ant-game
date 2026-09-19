import AppKit

/// The user's custom nest picture, stored as ~/Library/Application Support/GoblinCamp/nest.png
/// (a downscaled copy, so moving or deleting the original doesn't break it).
enum NestImageStore {
    private static let maxPixels: CGFloat = 256

    private static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("GoblinCamp/nest.png")
    }

    /// nil means "use the default dirt mound".
    /// (`CAMP_NO_NEST_IMAGE` ignores the saved picture, for testing the default mound.)
    private(set) static var image: NSImage? = ProcessInfo.processInfo.environment["CAMP_NO_NEST_IMAGE"] == nil ? NSImage(contentsOf: url) : nil

    @discardableResult
    static func importImage(from source: URL) -> Bool {
        guard let original = NSImage(contentsOf: source), let rep = original.representations.first else { return false }
        let pixelSize = CGSize(width: rep.pixelsWide > 0 ? rep.pixelsWide : Int(original.size.width),
                               height: rep.pixelsHigh > 0 ? rep.pixelsHigh : Int(original.size.height))
        guard pixelSize.width > 0, pixelSize.height > 0 else { return false }

        let scale = min(1, maxPixels / max(pixelSize.width, pixelSize.height))
        let w = max(1, Int(pixelSize.width * scale)), h = max(1, Int(pixelSize.height * scale))
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                                            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return false }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        original.draw(in: NSRect(x: 0, y: 0, width: w, height: h), from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        guard let png = bitmap.representation(using: .png, properties: [:]) else { return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try png.write(to: url, options: .atomic)
        } catch {
            NSLog("GoblinCamp: saving nest image failed: \(error)")
            return false
        }
        image = NSImage(contentsOf: url)
        return image != nil
    }

    static func remove() {
        try? FileManager.default.removeItem(at: url)
        image = nil
    }
}
