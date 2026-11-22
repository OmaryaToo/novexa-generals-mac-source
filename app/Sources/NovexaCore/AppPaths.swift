import Foundation

/// Standard Application Support layout for the launcher.
public struct AppPaths: Sendable {
    public let root: URL

    public init(root: URL? = nil) {
        if let root { self.root = root } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.root = base.appendingPathComponent("NOVEXA Generals Mac", isDirectory: true)
        }
    }

    public var settingsFile: URL { root.appendingPathComponent("settings.json") }
    public var engineDir: URL { root.appendingPathComponent("Engine", isDirectory: true) }
    public var configsDir: URL { root.appendingPathComponent("GameConfigs", isDirectory: true) }
    public var modsDir: URL { root.appendingPathComponent("Mods", isDirectory: true) }
    public var logsDir: URL { root.appendingPathComponent("Logs", isDirectory: true) }
    public var backupsDir: URL { root.appendingPathComponent("Backups", isDirectory: true) }
    public var cacheDir: URL { root.appendingPathComponent("Cache", isDirectory: true) }
    public var toolsDir: URL { root.appendingPathComponent("Tools", isDirectory: true) }

    public func configDir(for game: GameKind) -> URL { configsDir.appendingPathComponent(game.rawValue, isDirectory: true) }

    public func createAll() throws {
        for d in [root, toolsDir, engineDir, configsDir, modsDir, logsDir, backupsDir, cacheDir] + GameKind.allCases.map(configDir) {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
    }
}
