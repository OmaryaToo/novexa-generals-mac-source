import SwiftUI
import NovexaCore
import AppKit

@MainActor
final class AppModel: ObservableObject {
    let paths = AppPaths()
    let store: SettingsStore
    let mods: ModManager
    let runner = GameProcessRunner()

    @Published var settings: LauncherSettings { didSet { try? store.save(settings) } }
    @Published var reports: [GameKind: ValidationReport] = [:]
    @Published var engines: [GameKind: EngineInstallation] = [:]
    @Published var modList: [ModRecord] = []
    @Published var launchState: LaunchState = .idle
    @Published var runningGame: GameKind?
    @Published var consoleTail: [String] = []
    @Published var lastError: String?
    @Published var backups: [BackupRecord] = []
    @Published var showSteamSheet = false
    @Published var steamDownloadPending: [GameKind] = []
    private var steamWatcher: Timer?

    init() {
        try? paths.createAll()
        store = SettingsStore(url: paths.settingsFile)
        settings = store.load()
        mods = ModManager(root: paths.modsDir)
        migrateGraphicsDefaults()
        runner.onStateChange = { [weak self] s in Task { @MainActor in self?.handle(state: s) } }
        runner.onOutput = { [weak self] text in Task { @MainActor in self?.append(text) } }
        refresh()
        // First run (or paths lost): look in the known install locations automatically.
        if GameKind.allCases.allSatisfy({ settings[$0].installPath == nil }) { autoDetect() }
    }

    var backupManager: BackupManager { BackupManager(root: paths.backupsDir) }

    /// Native panel size in physical pixels (e.g. 3024×1964 on a 14" MacBook Pro).
    static var nativePixels: (Int, Int) {
        guard let s = NSScreen.main else { return (1920, 1080) }
        return (Int(s.frame.width * s.backingScaleFactor), Int(s.frame.height * s.backingScaleFactor))
    }

    /// First run with graphics support: enable the High preset at Retina resolution. The engine
    /// treats -xres/-yres as physical pixels on Retina (window = pixels ÷ 2 in points).
    private func migrateGraphicsDefaults() {
        for g in GameKind.allCases where settings[g].graphics == nil {
            settings[g].graphics = .make(.high)
            let (w, h) = Self.nativePixels
            if settings[g].displayMode == .fullscreen {
                settings[g].width = w; settings[g].height = h
            } else {
                settings[g].width = min(2560, w * 85 / 100); settings[g].height = settings[g].width * 9 / 16
            }
        }
    }

    func refresh() {
        for g in GameKind.allCases {
            reports[g] = InstallationValidator.validate(game: g, path: settings[g].installPath.map { URL(fileURLWithPath: $0) })
            engines[g] = EngineLocator.locate(game: g, paths: paths, override: settings.engineDirectory)
        }
        modList = mods.mods
        backups = backupManager.list()
    }

    func setInstall(_ url: URL, for game: GameKind) {
        settings[game].installPath = url.standardizedFileURL.path
        refresh()
    }

    func autoDetect() {
        for g in GameKind.allCases where !(reports[g]?.isLaunchable ?? false) {
            if let found = InstallationValidator.discover(game: g).first { settings[g].installPath = found.path }
        }
        refresh()
    }

    func chooseFolder(for game: GameKind) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.message = "Select your \(game.displayName) installation folder (the one containing the .big archives)."
        if panel.runModal() == .OK, let u = panel.url { setInstall(u, for: game) }
    }

    func play(_ game: GameKind) {
        guard runningGame == nil, launchState != .preparing else { return }
        lastError = nil; consoleTail = []
        launchState = .preparing
        refresh()
        let stock = engines[game], install = settings[game].installPath, paths = self.paths
        Task {
            // Copy/icon/re-sign happens off the main thread (only slow the first time).
            let gs = settings[game], backups = backupManager
            let mine = await Task.detached(priority: .userInitiated) { () -> EngineInstallation? in
                // Graphics → engine config (backed up before any change).
                if let gfx = gs.graphics {
                    try? GraphicsConfigWriter.apply(gfx, game: game, width: gs.width, height: gs.height,
                                                    userDir: GraphicsConfigWriter.userDataDir(game), backups: backups)
                }
                guard let stock else { return nil }
                return EnginePersonalizer.personalized(engine: stock, game: game, installPath: install, paths: paths)
            }.value
            do {
                let plan = try LaunchPlanner.plan(game: game, settings: settings, engine: mine ?? stock, mods: mods.mods, paths: paths)
                runningGame = game
                settings.lastPlayed = game; settings.lastPlayedDate = Date()
                try runner.start(plan)
            } catch {
                runningGame = nil
                launchState = .failed("\(error)")
                lastError = "\(error)"
            }
        }
    }

    func stopGame() { runner.stop() }

    private func handle(state: LaunchState) {
        launchState = state
        if case .failed(let m) = state { lastError = m; runningGame = nil }
        if state == .idle { runningGame = nil }
    }

    private func append(_ text: String) {
        consoleTail.append(contentsOf: text.split(separator: "\n").map(String.init))
        if consoleTail.count > 400 { consoleTail.removeFirst(consoleTail.count - 400) }
    }

    // MARK: Steam download
    /// Opens Terminal running SteamCMD for the user's own account; credentials are typed there only.
    func startSteamDownload(account: String, games: [GameKind]) {
        let name = account.trimmingCharacters(in: .whitespaces)
        do {
            let script = try SteamDownloader.script(account: name, games: games, toolsDir: paths.toolsDir,
                                                    existingSteamCMD: SteamDownloader.locateSteamCMD(toolsDir: paths.toolsDir))
            let url = try SteamDownloader.writeScript(script, cacheDir: paths.cacheDir)
            let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
            NSWorkspace.shared.open([url], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
            steamDownloadPending = games
            startSteamWatcher()
        } catch { lastError = "\(error)" }
    }

    private func startSteamWatcher() {
        steamWatcher?.invalidate()
        steamWatcher = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkSteamDownloads() }
        }
    }

    /// Links a downloaded folder once its archives validate. SteamCMD writes archives as it goes,
    /// so a folder is only linked when every required and recommended archive is present.
    func checkSteamDownloads() {
        for g in steamDownloadPending {
            let dir = SteamDownloader.defaultInstallDir(g)
            if InstallationValidator.validate(game: g, path: dir).status == .valid {
                settings[g].installPath = dir.path
                steamDownloadPending.removeAll { $0 == g }
            }
        }
        if steamDownloadPending.isEmpty { steamWatcher?.invalidate(); steamWatcher = nil }
        refresh()
    }

    func cancelSteamWatch() { steamDownloadPending = []; steamWatcher?.invalidate(); steamWatcher = nil }

    // MARK: Mods
    func importMod(games: [GameKind]) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = true
        panel.allowedContentTypes = [.zip, .folder, .data]
        panel.message = "Choose a mod (.big, .zip or folder)."
        guard panel.runModal() == .OK, let u = panel.url else { return }
        do { try mods.importMod(from: u, games: games) } catch { lastError = "\(error)" }
        refresh()
    }

    func toggleMod(_ m: ModRecord) { try? mods.setEnabled(m.id, !m.enabled); refresh() }

    func removeMod(_ m: ModRecord) {
        for g in GameKind.allCases where settings[g].activeModID == m.id { settings[g].activeModID = nil }
        do { try mods.remove(m.id, backupDir: paths.backupsDir) } catch { lastError = "\(error)" }
        refresh()
    }

    // MARK: Backups / diagnostics
    func backupNow() {
        do {
            try backupManager.backup(items: [paths.settingsFile, paths.configsDir, paths.modsDir.appendingPathComponent("mods.json")], label: "launcher")
        } catch { lastError = "\(error)" }
        refresh()
    }

    func restore(_ b: BackupRecord) {
        do { _ = try backupManager.restore(b.url); settings = store.load() } catch { lastError = "\(error)" }
        refresh()
    }

    func exportLogs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "NOVEXA-Diagnostics.zip"
        guard panel.runModal() == .OK, let u = panel.url else { return }
        do { try Diagnostics.exportLogs(settings: settings, paths: paths, to: u) } catch { lastError = "\(error)" }
    }
}
