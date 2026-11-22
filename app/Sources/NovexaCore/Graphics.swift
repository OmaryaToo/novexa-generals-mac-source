import Foundation

public enum GraphicsPreset: String, Codable, CaseIterable, Sendable, Identifiable {
    case balanced, high, ultra, custom
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

/// Graphics options the launcher writes into the engine's own config files before each launch.
/// Keys and value formats come from GeneralsX OptionPreferences.cpp / GlobalData.cpp.
public struct GraphicsSettings: Codable, Equatable, Sendable {
    public var preset: GraphicsPreset = .high
    /// 0 = uncapped. Engine presets: 30…480. Game logic always runs at 30 Hz.
    public var fpsLimit: Int = 120
    public var antiAliasing: Int = 4          // MSAA 0/2/4/8
    public var anisotropy: Int = 16           // 2/4/8/16
    public var fxaa = false
    public var bloom = false
    public var hdr = false
    public var advancedLighting = true
    public var advancedShadows = true
    public var shadows = true
    public var dynamicLights = true
    public var vehicleHeadlights = true
    public var waterReflections = true
    public var heatEffects = true
    public var extraAnimations = true
    public var terrainDrawDistance: Double = 1.05

    public init() {}

    public static func make(_ p: GraphicsPreset) -> GraphicsSettings {
        var g = GraphicsSettings(); g.preset = p
        switch p {
        case .balanced:
            g.fpsLimit = 60; g.antiAliasing = 2; g.anisotropy = 4
            g.advancedLighting = false; g.advancedShadows = false; g.dynamicLights = true
            g.vehicleHeadlights = false; g.waterReflections = true; g.terrainDrawDistance = 1.05
        case .high, .custom:
            break
        case .ultra:
            g.fpsLimit = 120; g.antiAliasing = 8; g.anisotropy = 16; g.fxaa = true; g.bloom = true
            g.terrainDrawDistance = 1.25
        }
        return g
    }

    static func yn(_ b: Bool) -> String { b ? "yes" : "no" }

    /// Key/value pairs merged into Options.ini. `StaticGameLOD = Custom` makes the engine use
    /// these individual values instead of its auto-detected preset.
    public func optionsEntries(width: Int, height: Int) -> [(String, String)] {
        [("Resolution", "\(width) \(height)"),
         ("StaticGameLOD", "Custom"), ("IdealStaticGameLOD", "High"),
         ("AntiAliasing", String(antiAliasing)),
         ("TextureFilter", "Anisotropic"), ("AnisotropyLevel", String(anisotropy)),
         ("TextureReduction", "0"),
         ("FPSLimit", Self.yn(fpsLimit > 0)),
         ("EnablePostProcessing", Self.yn(fxaa || bloom || hdr)),
         ("PostProcessFXAA", Self.yn(fxaa)), ("PostProcessBloom", Self.yn(bloom)), ("PostProcessHDR", Self.yn(hdr)),
         ("AdvancedLighting", Self.yn(advancedLighting)), ("AdvancedShadows", Self.yn(advancedShadows)),
         ("UseShadowVolumes", Self.yn(shadows)), ("UseShadowDecals", Self.yn(shadows)),
         ("ExplosionDynamicLights", Self.yn(dynamicLights)), ("VehicleHeadlights", Self.yn(vehicleHeadlights)),
         ("WaterReflections", Self.yn(waterReflections)), ("ShowSoftWaterEdge", Self.yn(waterReflections)),
         ("HeatEffects", Self.yn(heatEffects)), ("ExtraAnimations", Self.yn(extraAnimations)),
         ("ShowTrees", "yes"), ("UseCloudMap", "yes"), ("UseLightMap", "yes"),
         ("TerrainDrawDistanceScale", String(format: "%.2f", terrainDrawDistance))]
    }

    /// Key/value pairs merged into the `GameData` block of SagePatch.ini.
    public var sagePatchEntries: [(String, String)] {
        fpsLimit > 0
            ? [("UseFPSLimit", "Yes"), ("FramesPerSecondLimit", String(fpsLimit))]
            : [("UseFPSLimit", "No"), ("FramesPerSecondLimit", "1000")]
    }
}

/// Line-preserving `Key = Value` merge for the engine's INI-style files.
public enum IniMerge {
    /// Flat files like Options.ini: replace existing keys (case-insensitive), append missing ones.
    public static func mergeFlat(_ text: String, _ entries: [(String, String)]) -> String {
        var lines = text.isEmpty ? [] : text.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        for (k, v) in entries {
            if let i = lines.firstIndex(where: { key(of: $0)?.caseInsensitiveCompare(k) == .orderedSame }) {
                lines[i] = "\(k) = \(v)"
            } else { lines.append("\(k) = \(v)") }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Merge inside a named block (`GameData` … `End`); creates the block when absent.
    public static func mergeBlock(_ text: String, block: String, _ entries: [(String, String)]) -> String {
        var lines = text.isEmpty ? [] : text.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(block) == .orderedSame }),
              let endRel = lines[(start + 1)...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare("End") == .orderedSame })
        else {
            lines.append(block)
            for (k, v) in entries { lines.append("  \(k) = \(v)") }
            lines.append("End")
            return lines.joined(separator: "\n") + "\n"
        }
        var end = endRel
        for (k, v) in entries {
            if let i = lines[(start + 1)..<end].firstIndex(where: { key(of: $0)?.caseInsensitiveCompare(k) == .orderedSame }) {
                lines[i] = "  \(k) = \(v)"
            } else { lines.insert("  \(k) = \(v)", at: end); end += 1 }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func key(of line: String) -> String? {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard !t.hasPrefix(";"), let eq = t.firstIndex(of: "=") else { return nil }
        return t[..<eq].trimmingCharacters(in: .whitespaces)
    }
}

/// Writes graphics settings into the engine's per-game user data folder.
public enum GraphicsConfigWriter {
    /// GeneralsX user data: ~/Library/Application Support/GeneralsX/<Generals|GeneralsZH>.
    public static func userDataDir(_ game: GameKind, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library/Application Support/GeneralsX/\(game == .zeroHour ? "GeneralsZH" : "Generals")", isDirectory: true)
    }

    /// Applies settings; backs up the previous files first whenever their content changes.
    /// Returns true when anything was written.
    @discardableResult
    public static func apply(_ g: GraphicsSettings, game: GameKind, width: Int, height: Int,
                             userDir: URL, backups: BackupManager?) throws -> Bool {
        let fm = FileManager.default
        try fm.createDirectory(at: userDir, withIntermediateDirectories: true)
        let options = userDir.appendingPathComponent("Options.ini")
        let sage = userDir.appendingPathComponent("SagePatch.ini")
        let oldOptions = (try? String(contentsOf: options, encoding: .utf8)) ?? ""
        let oldSage = (try? String(contentsOf: sage, encoding: .utf8)) ?? ""
        let newOptions = IniMerge.mergeFlat(oldOptions, g.optionsEntries(width: width, height: height))
        let newSage = IniMerge.mergeBlock(oldSage, block: "GameData", g.sagePatchEntries)
        guard newOptions != oldOptions || newSage != oldSage else { return false }
        let existing = [options, sage].filter { fm.fileExists(atPath: $0.path) }
        if let backups, !existing.isEmpty { try backups.backup(items: existing, label: "graphics-\(game.rawValue)") }
        if newOptions != oldOptions { try newOptions.write(to: options, atomically: true, encoding: .utf8) }
        if newSage != oldSage { try newSage.write(to: sage, atomically: true, encoding: .utf8) }
        return true
    }
}
