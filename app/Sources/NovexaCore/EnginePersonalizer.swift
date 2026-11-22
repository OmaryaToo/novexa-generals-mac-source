import Foundation
import AppKit

/// Gives the running game the player's own official game icon in the Dock.
///
/// EA artwork can't ship inside NOVEXA, so on the player's Mac the launcher makes a private copy
/// of the engine app in Application Support, swaps its icon for one built from the `.ico` in the
/// player's own installation, and re-signs it ad hoc with the system `codesign`. The copy is
/// refreshed only when the engine version or the source icon changes. Any failure falls back to
/// the stock (Novexa-branded) engine, so launching never depends on this step.
public enum EnginePersonalizer {
    public static func iconSource(_ game: GameKind, installPath: String?) -> URL? {
        guard let dir = installPath else { return nil }
        let names = game == .zeroHour ? ["GeneralsZH.ico", "Generals.ico"] : ["Generals.ico"]
        let items = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        for n in names {
            if let m = items.first(where: { $0.caseInsensitiveCompare(n) == .orderedSame }) {
                return URL(fileURLWithPath: dir).appendingPathComponent(m)
            }
        }
        return nil
    }

    /// Stamp identifying what a personalized copy was built from.
    static func stamp(engine: EngineInstallation, icon: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: icon.path)
        let size = (attrs?[.size] as? NSNumber)?.intValue ?? 0
        let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let binAttrs = try? FileManager.default.attributesOfItem(atPath: engine.binary.path)
        let binSize = (binAttrs?[.size] as? NSNumber)?.intValue ?? 0
        let binTime = Int((binAttrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)
        return "\(engine.version ?? "?")|\(binSize)|\(binTime)|\(icon.lastPathComponent)|\(size)|\(Int(mtime))"
    }

    /// Returns the personalized engine (creating/refreshing it if needed), or nil to use the stock one.
    public static func personalized(engine: EngineInstallation, game: GameKind, installPath: String?,
                                    paths: AppPaths) -> EngineInstallation? {
        guard let icon = iconSource(game, installPath: installPath) else { return nil }
        // Stock engine must be in bundle layout: <Name>.app/Contents/MacOS
        let stockApp = engine.directory.deletingLastPathComponent().deletingLastPathComponent()
        guard stockApp.pathExtension == "app" else { return nil }
        let fm = FileManager.default
        // Migration from <= 0.1.1: the old folder was visible to Spotlight/Launchpad. It's only a cache.
        try? fm.removeItem(at: paths.engineDir.appendingPathComponent("personalized", isDirectory: true))
        // ".noindex" keeps these helper apps out of Spotlight and Launchpad: players start games from the launcher.
        let destDir = paths.engineDir.appendingPathComponent("personalized.noindex/\(game.rawValue)", isDirectory: true)
        let destApp = destDir.appendingPathComponent(stockApp.lastPathComponent)
        let stampFile = destDir.appendingPathComponent("stamp.txt")
        let want = stamp(engine: engine, icon: icon)

        if (try? String(contentsOf: stampFile, encoding: .utf8)) != want || !fm.fileExists(atPath: destApp.path) {
            do {
                try? fm.removeItem(at: destDir)
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
                try fm.copyItem(at: stockApp, to: destApp)
                try writeICNS(from: icon, to: destApp.appendingPathComponent("Contents/Resources/AppIcon.icns"))
                try run("/usr/bin/codesign", ["--force", "--sign", "-", destApp.path])
                try want.write(to: stampFile, atomically: true, encoding: .utf8)
            } catch {
                try? fm.removeItem(at: destDir)
                return nil
            }
        }
        return EngineLocator.inspect(directory: destDir, game: game).flatMap { $0.isUsable ? $0 : nil }
    }

    /// Converts any image AppKit can read (.ico, .bmp, .png) to .icns via the system iconutil.
    static func writeICNS(from src: URL, to dst: URL) throws {
        guard let image = NSImage(contentsOf: src) else { throw ModError.io("cannot read \(src.lastPathComponent)") }
        let set = FileManager.default.temporaryDirectory.appendingPathComponent("novexa-\(UUID().uuidString).iconset")
        try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: set) }
        for (name, px) in [("16x16",16),("16x16@2x",32),("32x32",32),("32x32@2x",64),("128x128",128),
                           ("128x128@2x",256),("256x256",256),("256x256@2x",512),("512x512",512),("512x512@2x",1024)] {
            guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                             bytesPerRow: 0, bitsPerPixel: 0) else { continue }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSGraphicsContext.current?.imageInterpolation = .high
            // Small margin like standard macOS icons.
            let m = CGFloat(px) * 0.06
            image.draw(in: NSRect(x: m, y: m, width: CGFloat(px) - 2*m, height: CGFloat(px) - 2*m))
            NSGraphicsContext.restoreGraphicsState()
            try rep.representation(using: .png, properties: [:])?.write(to: set.appendingPathComponent("icon_\(name).png"))
        }
        try? FileManager.default.removeItem(at: dst)
        try run("/usr/bin/iconutil", ["-c", "icns", set.path, "-o", dst.path])
    }

    static func run(_ exe: String, _ args: [String]) throws {
        let p = Process(); p.executableURL = URL(fileURLWithPath: exe); p.arguments = args
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw ModError.io("\(exe) failed (\(p.terminationStatus))") }
    }
}
