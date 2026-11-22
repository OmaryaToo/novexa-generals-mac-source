import Foundation

public enum DisplayMode: String, Codable, CaseIterable, Sendable { case windowed, fullscreen }

public struct GameSettings: Codable, Equatable, Sendable {
    public var installPath: String?
    public var activeModID: String?
    public var displayMode: DisplayMode = .windowed
    public var width: Int = 1600
    public var height: Int = 900
    public var extraArguments: String = ""
    public var graphics: GraphicsSettings? = nil
    /// Apple's Metal Performance HUD (FPS, frame time, GPU) drawn over the game window.
    public var showPerformanceHUD: Bool? = nil   // nil = launcher doesn't touch the engine's graphics files
    public init() {}
}

public struct LauncherSettings: Codable, Equatable, Sendable {
    public var generals = GameSettings()
    public var zeroHour = GameSettings()
    /// Optional override for the directory holding the built engine.
    public var engineDirectory: String?
    public var lastPlayed: GameKind?
    public var lastPlayedDate: Date?
    public var musicVolume: Double = 0.7
    public var sfxVolume: Double = 0.8
    public var voiceVolume: Double = 0.8
    public var muted: Bool = false
    public var online: OnlineSettings? = nil
    public init() {}

    public subscript(game: GameKind) -> GameSettings {
        get { game == .generals ? generals : zeroHour }
        set { if game == .generals { generals = newValue } else { zeroHour = newValue } }
    }
}

public struct SettingsStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }

    public func load() -> LauncherSettings {
        guard let data = try? Data(contentsOf: url),
              let s = try? JSONDecoder.novexa.decode(LauncherSettings.self, from: data) else { return LauncherSettings() }
        return s
    }

    public func save(_ s: LauncherSettings) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder.novexa.encode(s).write(to: url, options: .atomic)
    }
}

extension JSONEncoder {
    static var novexa: JSONEncoder {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; e.dateEncodingStrategy = .iso8601; return e
    }
}
extension JSONDecoder {
    static var novexa: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}
