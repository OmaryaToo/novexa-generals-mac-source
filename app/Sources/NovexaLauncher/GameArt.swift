import AppKit
import NovexaCore

/// Official artwork read at runtime from the player's OWN installation folder.
/// Nothing from EA is bundled with NOVEXA; if the folder isn't set, the UI uses brand artwork.
@MainActor
enum GameArt {
    private static var cache: [String: NSImage] = [:]

    private static func file(_ names: [String], in dir: String?) -> NSImage? {
        guard let dir else { return nil }
        let items = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        for n in names {
            guard let match = items.first(where: { $0.caseInsensitiveCompare(n) == .orderedSame }) else { continue }
            let path = (dir as NSString).appendingPathComponent(match)
            if let c = cache[path] { return c }
            if let img = NSImage(contentsOfFile: path) { cache[path] = img; return img }
        }
        return nil
    }

    /// 800×600 cover with the game logo (Install_Final.bmp ships with Steam/EA/retail installs).
    /// Cropped to the inner artwork: drops the installer frame border and the publisher badge
    /// at the bottom so only the scene and game logo remain.
    static func cover(_ game: GameKind, installPath: String?) -> NSImage? {
        guard let full = file(["Install_Final.bmp"], in: installPath) else { return nil }
        let key = "crop:\(installPath ?? ""):\(game.rawValue)"
        if let c = cache[key] { return c }
        guard let cg = full.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return full }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        // Fractions measured on the 800×600 retail art (frame ≈ 9% inset, badge starts at ≈ 85% height).
        let rect = CGRect(x: w * 0.095, y: h * 0.10, width: w * 0.81, height: h * 0.74).integral
        guard let cropped = cg.cropping(to: rect) else { return full }
        let img = NSImage(cgImage: cropped, size: NSSize(width: rect.width, height: rect.height))
        cache[key] = img
        return img
    }

    /// Wide banner (launcher.bmp).
    static func banner(_ game: GameKind, installPath: String?) -> NSImage? {
        file(["launcher.bmp"], in: installPath)
    }

    /// Faction emblem icon.
    static func emblem(_ game: GameKind, installPath: String?) -> NSImage? {
        file(game == .zeroHour ? ["GeneralsZH.ico", "Generals.ico"] : ["Generals.ico"], in: installPath)
    }
}
