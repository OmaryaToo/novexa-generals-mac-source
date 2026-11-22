import Foundation

public enum LaunchState: Equatable, Sendable {
    case idle, preparing, loading, running(pid: Int32), exiting, failed(String)
    public var label: String {
        switch self {
        case .idle: return "Idle"
        case .preparing: return "Preparing"
        case .loading: return "Loading"
        case .running: return "Running"
        case .exiting: return "Exiting"
        case .failed: return "Failed"
        }
    }
}

public enum LaunchError: Error, CustomStringConvertible, Equatable {
    case installation(String), engine(String), mod(String), process(String)
    public var description: String {
        switch self {
        case .installation(let s): return "Game data: \(s)"
        case .engine(let s): return "Engine: \(s)"
        case .mod(let s): return "Mod: \(s)"
        case .process(let s): return "Process: \(s)"
        }
    }
}

/// Everything needed to start the engine; built and validated before any process runs.
public struct LaunchPlan: Equatable, Sendable {
    public var executable: URL
    public var arguments: [String]
    public var environment: [String: String]
    public var workingDirectory: URL
    public var logFile: URL
}

public enum LaunchPlanner {
    /// Base-game data Zero Hour needs: the `ZH_Generals` folder shipped inside Steam/EA App
    /// Zero Hour installs, otherwise the separately configured Generals installation.
    public static func generalsDataForZeroHour(zeroHourDir: URL, settings: LauncherSettings) -> URL? {
        let bundled = zeroHourDir.appendingPathComponent("ZH_Generals", isDirectory: true)
        if InstallationValidator.validate(game: .generals, path: bundled).isLaunchable { return bundled }
        if let g = settings.generals.installPath {
            let u = URL(fileURLWithPath: g)
            if InstallationValidator.validate(game: .generals, path: u).isLaunchable { return u }
        }
        return nil
    }

    public static func plan(game: GameKind, settings: LauncherSettings, engine: EngineInstallation?,
                            mods: [ModRecord], paths: AppPaths, date: Date = Date()) throws -> LaunchPlan {
        let gs = settings[game]
        let report = InstallationValidator.validate(game: game, path: gs.installPath.map { URL(fileURLWithPath: $0) })
        guard report.isLaunchable, let dataDir = report.path else { throw LaunchError.installation(report.summary) }

        guard let engine else { throw LaunchError.engine("GeneralsX engine for \(game.displayName) is not installed") }
        guard engine.architecture == .arm64 else { throw LaunchError.engine("Engine binary is \(engine.architecture.rawValue), expected arm64") }
        guard engine.missingComponents.isEmpty else { throw LaunchError.engine("Missing runtime libraries: " + engine.missingComponents.joined(separator: ", ")) }

        var args = ["-assetPath", dataDir.path]
        if game == .zeroHour, let g = generalsDataForZeroHour(zeroHourDir: dataDir, settings: settings) {
            args += ["-generalsAssetPath", g.path]
        }
        switch gs.displayMode {
        case .windowed: args.append("-win")
        case .fullscreen: args.append("-fullscreen")
        }
        args += ["-xres", String(max(640, gs.width)), "-yres", String(max(480, gs.height))]
        if settings.muted { args += ["-noaudio"] }

        if let modID = gs.activeModID {
            guard let mod = mods.first(where: { $0.id == modID }) else { throw LaunchError.mod("Selected mod no longer exists") }
            guard mod.games.contains(game) else { throw LaunchError.mod("\(mod.name) is not marked compatible with \(game.displayName)") }
            guard FileManager.default.fileExists(atPath: mod.contentPath) else { throw LaunchError.mod("Mod files missing at \(mod.contentPath)") }
            args += ["-mod", mod.contentPath]
        }
        args += ExtraArguments.parse(gs.extraArguments)

        let dir = engine.directory
        let res = engine.resources
        var env = ProcessInfo.processInfo.environment
        env["DYLD_LIBRARY_PATH"] = dir.path
        env["VK_ICD_FILENAMES"] = res.appendingPathComponent("MoltenVK_icd.json").path
        env["VK_INSTANCE_LAYERS"] = ""
        env["DXVK_WSI_DRIVER"] = "SDL3"
        let dxvkConf = res.appendingPathComponent("dxvk.conf")
        if FileManager.default.fileExists(atPath: dxvkConf.path) { env["DXVK_CONFIG_FILE"] = dxvkConf.path }
        let fonts = res.appendingPathComponent("fontconfig/fonts.conf")
        if FileManager.default.fileExists(atPath: fonts.path) {
            env["FONTCONFIG_FILE"] = fonts.path; env["FONTCONFIG_PATH"] = fonts.deletingLastPathComponent().path
        }
        // All engine-side writes go to Application Support, never into the signed app bundle.
        let work = paths.cacheDir.appendingPathComponent(game.rawValue, isDirectory: true)
        try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        env["DXVK_STATE_CACHE_PATH"] = work.path
        env["DXVK_LOG_PATH"] = paths.logsDir.path
        env["XDG_CACHE_HOME"] = work.path
        // Players always use NOVEXA Online; saved per-user choices are ignored on purpose.
        for (k, v) in OnlineSettings.effective().environment { env[k] = v }
        if gs.showPerformanceHUD == true { env["MTL_HUD_ENABLED"] = "1" } else { env.removeValue(forKey: "MTL_HUD_ENABLED") }
        env["CNC_GENERALS_PATH"] = settings.generals.installPath ?? ""
        if game == .zeroHour { env["CNC_GENERALS_ZH_PATH"] = dataDir.path }

        let stamp = ISO8601DateFormatter().string(from: date).replacingOccurrences(of: ":", with: "-")
        let log = paths.logsDir.appendingPathComponent("\(game.rawValue)-\(stamp).log")
        return LaunchPlan(executable: engine.binary, arguments: args, environment: env, workingDirectory: work, logFile: log)
    }
}

/// Splits user-entered extra arguments; only engine-style flags/values are accepted (no shell).
public enum ExtraArguments {
    public static func parse(_ s: String) -> [String] {
        var out: [String] = []; var cur = ""; var quoted = false
        for ch in s {
            if ch == "\"" { quoted.toggle(); continue }
            if ch == " " && !quoted { if !cur.isEmpty { out.append(cur); cur = "" } } else { cur.append(ch) }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }
}

/// Runs the engine process, streams its output to a log file and reports state.
public final class GameProcessRunner: @unchecked Sendable {
    private var process: Process?
    public private(set) var state: LaunchState = .idle
    public var onStateChange: (@Sendable (LaunchState) -> Void)?
    public var onOutput: (@Sendable (String) -> Void)?

    public init() {}

    public func start(_ plan: LaunchPlan) throws {
        set(.loading)
        FileManager.default.createFile(atPath: plan.logFile.path, contents: nil)
        let log = try FileHandle(forWritingTo: plan.logFile)
        let header = "# NOVEXA launch \(Date())\n# \(plan.executable.path) \(plan.arguments.joined(separator: " "))\n"
        log.write(Data(header.utf8))

        let p = Process()
        p.executableURL = plan.executable
        p.arguments = plan.arguments
        p.environment = plan.environment
        p.currentDirectoryURL = plan.workingDirectory
        let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let d = h.availableData
            guard !d.isEmpty else { return }
            log.write(d)
            if let s = String(data: d, encoding: .utf8) { self?.onOutput?(s) }
        }
        p.terminationHandler = { [weak self] proc in
            pipe.fileHandleForReading.readabilityHandler = nil
            let tail = "# exited status=\(proc.terminationStatus) reason=\(proc.terminationReason == .exit ? "exit" : "signal")\n"
            log.write(Data(tail.utf8)); try? log.close()
            if proc.terminationStatus == 0 || self?.state == .exiting { self?.set(.idle) }
            else { self?.set(.failed("Engine exited with status \(proc.terminationStatus). See \(plan.logFile.lastPathComponent)")) }
            self?.process = nil
        }
        do { try p.run() } catch {
            try? log.close(); set(.failed(error.localizedDescription)); throw LaunchError.process(error.localizedDescription)
        }
        process = p
        set(.running(pid: p.processIdentifier))
    }

    /// Requests a graceful exit (SIGTERM), escalating to SIGKILL after a timeout.
    public func stop(timeout: TimeInterval = 5) {
        guard let p = process, p.isRunning else { return }
        set(.exiting)
        p.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { if p.isRunning { kill(p.processIdentifier, SIGKILL) } }
    }

    private func set(_ s: LaunchState) { state = s; onStateChange?(s) }
}
