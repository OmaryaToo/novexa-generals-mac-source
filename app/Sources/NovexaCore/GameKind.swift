import Foundation

/// The two games the launcher manages.
public enum GameKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case generals
    case zeroHour

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .generals: return "Generals"
        case .zeroHour: return "Zero Hour"
        }
    }

    /// Name of the GeneralsX engine executable built for this game.
    public var engineBinaryName: String {
        switch self {
        case .generals: return "GeneralsX"
        case .zeroHour: return "GeneralsXZH"
        }
    }

    /// Archives that must exist for the engine to boot. Derived from the archive
    /// names referenced in the GeneralsX engine source (INI data + textures).
    public var requiredArchives: [String] {
        switch self {
        case .generals: return ["INI.big", "Textures.big", "W3D.big", "Window.big"]
        case .zeroHour: return ["INIZH.big", "TexturesZH.big", "W3DZH.big", "WindowZH.big"]
        }
    }

    /// Archives that are normally present; missing ones are reported as warnings.
    public var recommendedArchives: [String] {
        switch self {
        case .generals: return ["Maps.big", "Terrain.big", "English.big", "Audio.big", "Music.big", "Speech.big", "Shaders.big"]
        case .zeroHour: return ["MapsZH.big", "TerrainZH.big", "EnglishZH.big", "AudioZH.big", "MusicZH.big", "ShadersZH.big"]
        }
    }
}
