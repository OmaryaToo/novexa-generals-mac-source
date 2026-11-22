import Foundation

public enum MachOArch: String, Sendable { case arm64, x86_64, universal, unknown, notMachO }

public enum MachO {
    /// Reads the Mach-O header to determine the CPU architecture actually built.
    public static func architecture(of url: URL) -> MachOArch {
        guard let h = try? FileHandle(forReadingFrom: url) else { return .notMachO }
        defer { try? h.close() }
        guard let d = try? h.read(upToCount: 8), d.count == 8 else { return .notMachO }
        let magic = d.prefix(4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        let cpu = d.suffix(4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        switch magic {
        case 0xfeedfacf: // MH_MAGIC_64, little endian
            if cpu == 0x0100000c { return .arm64 }
            if cpu == 0x01000007 { return .x86_64 }
            return .unknown
        case 0xbebafeca, 0xbfbafeca: return .universal // FAT_MAGIC(_64) read little-endian
        default: return .notMachO
        }
    }
}

public struct EngineInstallation: Equatable, Sendable {
    public var game: GameKind
    public var directory: URL
    public var binary: URL
    public var architecture: MachOArch
    public var missingComponents: [String]
    public var isUsable: Bool { missingComponents.isEmpty && architecture == .arm64 }
    public var version: String?
    /// Config files (MoltenVK ICD, dxvk.conf, fontconfig). `Contents/Resources` for bundled
    /// engines; the engine directory itself for the legacy flat layout.
    public var resourcesDirectory: URL? = nil
    public var resources: URL { resourcesDirectory ?? directory }
}

public enum EngineLocator {
    /// Runtime libraries the GeneralsX macOS build loads next to the executable.
    public static let requiredLibraries = ["libSDL3.0.dylib", "libdxvk_d3d8.0.dylib", "libdxvk_d3d9.0.dylib", "libMoltenVK.dylib", "libvulkan.1.dylib"]

    public static func candidateDirectories(game: GameKind, paths: AppPaths, override: String?) -> [URL] {
        var dirs: [URL] = []
        if let override, !override.isEmpty { dirs.append(URL(fileURLWithPath: override).appendingPathComponent(game.rawValue)) ; dirs.append(URL(fileURLWithPath: override)) }
        if let res = Bundle.main.resourceURL { dirs.append(res.appendingPathComponent("Engine/\(game.rawValue)")) }
        dirs.append(paths.engineDir.appendingPathComponent(game.rawValue))
        if let dev = ProcessInfo.processInfo.environment["NOVEXA_ROOT"] {
            dirs.append(URL(fileURLWithPath: dev).appendingPathComponent("build/runtime/\(game.rawValue)"))
        }
        return dirs
    }

    /// Display name of the engine app bundle (shown in the Dock while playing).
    public static func bundleName(_ game: GameKind) -> String {
        // Neutral names: EA's license terms forbid EA trademarks in distributed modifications.
        game == .zeroHour ? "NOVEXA ZH.app" : "NOVEXA Classic.app"
    }

    /// Accepts either `<dir>/<Name>.app` (current layout) or a flat directory (legacy).
    public static func inspect(directory: URL, game: GameKind) -> EngineInstallation? {
        let app = directory.appendingPathComponent(bundleName(game))
        if FileManager.default.fileExists(atPath: app.path),
           var e = inspectFlat(directory: app.appendingPathComponent("Contents/MacOS"), game: game,
                               resources: app.appendingPathComponent("Contents/Resources")) {
            e.resourcesDirectory = app.appendingPathComponent("Contents/Resources")
            return e
        }
        return inspectFlat(directory: directory, game: game, resources: directory)
    }

    static func inspectFlat(directory: URL, game: GameKind, resources: URL) -> EngineInstallation? {
        let bin = directory.appendingPathComponent(game.engineBinaryName)
        guard FileManager.default.isExecutableFile(atPath: bin.path) else { return nil }
        let missing = requiredLibraries.filter { !FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path) }
        let version = try? String(contentsOf: resources.appendingPathComponent("ENGINE_VERSION"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return EngineInstallation(game: game, directory: directory, binary: bin, architecture: MachO.architecture(of: bin),
                                  missingComponents: missing, version: version)
    }

    public static func locate(game: GameKind, paths: AppPaths, override: String?) -> EngineInstallation? {
        for d in candidateDirectories(game: game, paths: paths, override: override) {
            if let e = inspect(directory: d, game: game) { return e }
        }
        return nil
    }
}
