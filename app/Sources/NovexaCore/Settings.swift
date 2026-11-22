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

    /// Decoding is field-by-field and tolerant (see init(from:) below), so an unknown or missing value
    /// never wipes the rest. If the file is unreadable as a whole it is kept as settings.unreadable-<date>.json
    /// instead of being silently overwritten.
    public func load() -> LauncherSettings {
        guard let data = try? Data(contentsOf: url) else { return LauncherSettings() }
        if let s = try? JSONDecoder.novexa.decode(LauncherSettings.self, from: data) { return s }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        try? FileManager.default.copyItem(at: url, to: url.deletingLastPathComponent().appendingPathComponent("settings.unreadable-\(stamp).json"))
        return LauncherSettings()
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


// MARK: - Tolerant decoding (forward/backward compatible settings)

extension KeyedDecodingContainer {
    /// Missing key, null, wrong type or unknown enum case -> fallback, never an error.
    func lenient<T: Decodable>(_ key: Key, _ fallback: T) -> T { (try? decodeIfPresent(T.self, forKey: key)) ?? nil ?? fallback }
    func lenientOptional<T: Decodable>(_ key: Key) -> T? { (try? decodeIfPresent(T.self, forKey: key)) ?? nil }
}

extension GameSettings {
    enum CodingKeys: String, CodingKey { case installPath, activeModID, displayMode, width, height, extraArguments, graphics, showPerformanceHUD }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self); let d = GameSettings.init()
        self.init()
        installPath = c.lenientOptional(.installPath); activeModID = c.lenientOptional(.activeModID)
        displayMode = c.lenient(.displayMode, d.displayMode); width = c.lenient(.width, d.width); height = c.lenient(.height, d.height)
        extraArguments = c.lenient(.extraArguments, d.extraArguments)
        graphics = c.lenientOptional(.graphics); showPerformanceHUD = c.lenientOptional(.showPerformanceHUD)
    }
}

extension LauncherSettings {
    enum CodingKeys: String, CodingKey { case generals, zeroHour, engineDirectory, lastPlayed, lastPlayedDate, musicVolume, sfxVolume, voiceVolume, muted, online }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self); let d = LauncherSettings.init()
        self.init()
        generals = c.lenient(.generals, d.generals); zeroHour = c.lenient(.zeroHour, d.zeroHour)
        engineDirectory = c.lenientOptional(.engineDirectory); lastPlayed = c.lenientOptional(.lastPlayed)
        lastPlayedDate = c.lenientOptional(.lastPlayedDate)
        musicVolume = c.lenient(.musicVolume, d.musicVolume); sfxVolume = c.lenient(.sfxVolume, d.sfxVolume)
        voiceVolume = c.lenient(.voiceVolume, d.voiceVolume); muted = c.lenient(.muted, d.muted)
        online = c.lenientOptional(.online)
    }
}
