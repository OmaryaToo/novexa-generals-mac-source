import XCTest
@testable import NovexaCore

final class CoreTests: XCTestCase {
    var tmp: URL!
    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("novexa-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: tmp) }

    /// Synthetic BIG archive: only the 4-byte magic, no game content.
    func fakeBig(_ dir: URL, _ name: String, magic: String = "BIGF") throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data((magic + "\0\0\0\0").utf8).write(to: dir.appendingPathComponent(name))
    }

    // MARK: Detection / validation
    func testNotConfigured() {
        XCTAssertEqual(InstallationValidator.validate(game: .zeroHour, path: nil).status, .notConfigured)
    }
    func testMissingFolder() {
        XCTAssertEqual(InstallationValidator.validate(game: .zeroHour, path: tmp.appendingPathComponent("nope")).status, .missingFolder)
    }
    func testInvalidWhenRequiredMissing() throws {
        try fakeBig(tmp, "INIZH.big")
        let r = InstallationValidator.validate(game: .zeroHour, path: tmp)
        XCTAssertEqual(r.status, .invalid)
        XCTAssertTrue(r.missingRequired.contains("TexturesZH.big"))
        XCTAssertFalse(r.isLaunchable)
    }
    func testIncompleteButLaunchable() throws {
        for f in GameKind.zeroHour.requiredArchives { try fakeBig(tmp, f.lowercased()) } // case-insensitive
        let r = InstallationValidator.validate(game: .zeroHour, path: tmp)
        XCTAssertEqual(r.status, .incomplete)
        XCTAssertTrue(r.isLaunchable)
    }
    func testValid() throws {
        for f in GameKind.generals.requiredArchives + GameKind.generals.recommendedArchives { try fakeBig(tmp, f) }
        XCTAssertEqual(InstallationValidator.validate(game: .generals, path: tmp).status, .valid)
    }
    func testCorruptRequiredArchiveIsInvalid() throws {
        for f in GameKind.generals.requiredArchives { try fakeBig(tmp, f) }
        try fakeBig(tmp, "INI.big", magic: "XXXX")
        let r = InstallationValidator.validate(game: .generals, path: tmp)
        XCTAssertEqual(r.status, .invalid)
        XCTAssertEqual(r.invalidArchives, ["INI.big"])
    }
    func testDiscoverFindsValidCandidateOnly() throws {
        let home = tmp!
        for f in GameKind.zeroHour.requiredArchives { try fakeBig(home.appendingPathComponent("GeneralsX/GeneralsZH"), f) }
        try FileManager.default.createDirectory(at: home.appendingPathComponent("Games/Zero Hour"), withIntermediateDirectories: true)
        let found = InstallationValidator.discover(game: .zeroHour, home: home)
        XCTAssertEqual(found.map(\.lastPathComponent), ["GeneralsZH"])
    }

    // MARK: Paths
    func testSafeJoinRejectsTraversal() {
        XCTAssertThrowsError(try PathSecurity.safeJoin(root: tmp, relative: "../etc/passwd"))
        XCTAssertThrowsError(try PathSecurity.safeJoin(root: tmp, relative: "/etc/passwd"))
        XCTAssertThrowsError(try PathSecurity.safeJoin(root: tmp, relative: "a/../../b"))
        XCTAssertNoThrow(try PathSecurity.safeJoin(root: tmp, relative: "Data/INI/x.ini"))
    }
    func testSafeJoinRejectsSymlinkEscape() throws {
        try FileManager.default.createSymbolicLink(at: tmp.appendingPathComponent("link"), withDestinationURL: URL(fileURLWithPath: "/private/etc"))
        XCTAssertThrowsError(try PathSecurity.safeJoin(root: tmp, relative: "link/hosts"))
    }
    func testSanitizedName() {
        XCTAssertEqual(PathSecurity.sanitizedName("../Rise/of*Reds"), "_Rise_of_Reds")
        XCTAssertEqual(PathSecurity.sanitizedName(""), "Unnamed")
    }

    // MARK: Settings
    func testSettingsRoundTrip() throws {
        let store = SettingsStore(url: tmp.appendingPathComponent("s.json"))
        var s = LauncherSettings(); s.zeroHour.installPath = "/x"; s.zeroHour.width = 2560; s.lastPlayed = .zeroHour; s.lastPlayedDate = Date(timeIntervalSince1970: 1000)
        try store.save(s)
        XCTAssertEqual(store.load(), s)
    }
    func testCorruptSettingsFallsBackToDefaults() throws {
        let u = tmp.appendingPathComponent("s.json"); try Data("{garbage".utf8).write(to: u)
        XCTAssertEqual(SettingsStore(url: u).load(), LauncherSettings())
    }

    // MARK: Engine
    func testMachOArchitectureOfLauncherTestBinary() {
        // /bin/ls is a universal binary on macOS; a non-Mach-O file must be rejected.
        XCTAssertEqual(MachO.architecture(of: URL(fileURLWithPath: "/bin/ls")), .universal)
        let f = tmp.appendingPathComponent("x"); try? Data("hello world".utf8).write(to: f)
        XCTAssertEqual(MachO.architecture(of: f), .notMachO)
    }
    func testEngineInspectReportsMissingLibraries() throws {
        let dir = tmp.appendingPathComponent("eng")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let bin = dir.appendingPathComponent("GeneralsXZH")
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: bin)
        let e = try XCTUnwrap(EngineLocator.inspect(directory: dir, game: .zeroHour))
        XCTAssertEqual(e.missingComponents.count, EngineLocator.requiredLibraries.count)
        XCTAssertFalse(e.isUsable)
    }

    // MARK: Launch planning
    func makeEngine() -> EngineInstallation {
        EngineInstallation(game: .zeroHour, directory: tmp, binary: tmp.appendingPathComponent("GeneralsXZH"), architecture: .arm64, missingComponents: [], version: nil)
    }
    func testPlanFailsWithoutData() {
        XCTAssertThrowsError(try LaunchPlanner.plan(game: .zeroHour, settings: LauncherSettings(), engine: makeEngine(), mods: [], paths: AppPaths(root: tmp)))
    }
    func testPlanFailsWithWrongArch() throws {
        let data = tmp.appendingPathComponent("zh"); for f in GameKind.zeroHour.requiredArchives { try fakeBig(data, f) }
        var s = LauncherSettings(); s.zeroHour.installPath = data.path
        var e = makeEngine(); e.architecture = .x86_64
        XCTAssertThrowsError(try LaunchPlanner.plan(game: .zeroHour, settings: s, engine: e, mods: [], paths: AppPaths(root: tmp))) {
            guard case LaunchError.engine = $0 else { return XCTFail() }
        }
    }
    func testPlanArguments() throws {
        let zh = tmp.appendingPathComponent("zh"); for f in GameKind.zeroHour.requiredArchives { try fakeBig(zh, f) }
        let gen = tmp.appendingPathComponent("gen"); for f in GameKind.generals.requiredArchives { try fakeBig(gen, f) }
        var s = LauncherSettings()
        s.zeroHour.installPath = zh.path; s.generals.installPath = gen.path
        s.zeroHour.displayMode = .fullscreen; s.zeroHour.width = 1920; s.zeroHour.height = 1080
        s.zeroHour.extraArguments = "-noshellmap \"-map\" x"
        let p = try LaunchPlanner.plan(game: .zeroHour, settings: s, engine: makeEngine(), mods: [], paths: AppPaths(root: tmp))
        XCTAssertEqual(p.arguments, ["-assetPath", zh.path, "-generalsAssetPath", gen.path, "-fullscreen", "-xres", "1920", "-yres", "1080", "-noshellmap", "-map", "x"])
        XCTAssertEqual(p.environment["DXVK_WSI_DRIVER"], "SDL3")
        XCTAssertEqual(p.environment["DYLD_LIBRARY_PATH"], tmp.path)
    }
    func testPlanRejectsIncompatibleMod() throws {
        let zh = tmp.appendingPathComponent("zh"); for f in GameKind.zeroHour.requiredArchives { try fakeBig(zh, f) }
        var s = LauncherSettings(); s.zeroHour.installPath = zh.path; s.zeroHour.activeModID = "m"
        let mod = ModRecord(id: "m", name: "M", games: [.generals], enabled: true, importedAt: Date(), contentPath: tmp.path, files: [])
        XCTAssertThrowsError(try LaunchPlanner.plan(game: .zeroHour, settings: s, engine: makeEngine(), mods: [mod], paths: AppPaths(root: tmp)))
    }

    // MARK: Mods
    func testModImportBigAndConflicts() throws {
        let mm = ModManager(root: tmp.appendingPathComponent("mods"))
        try fakeBig(tmp, "ModA.big")
        let src = tmp.appendingPathComponent("folderMod/Data/INI"); try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: src.appendingPathComponent("weapon.ini"))
        let a = try mm.importMod(from: tmp.appendingPathComponent("ModA.big"), games: [.zeroHour])
        let b = try mm.importMod(from: tmp.appendingPathComponent("folderMod"), games: [.zeroHour])
        let c = try mm.importMod(from: tmp.appendingPathComponent("folderMod"), name: "Copy", games: [.zeroHour])
        XCTAssertEqual(a.files, ["moda.big"])
        XCTAssertEqual(mm.conflicts(for: .zeroHour).keys.sorted(), ["data/ini/weapon.ini"])
        try mm.setEnabled(c.id, false)
        XCTAssertTrue(mm.conflicts(for: .zeroHour).isEmpty)
        // persisted
        XCTAssertEqual(ModManager(root: tmp.appendingPathComponent("mods")).mods.count, 3)
        _ = b
    }
    func testModRejectsUnsupported() throws {
        let mm = ModManager(root: tmp.appendingPathComponent("mods"))
        let f = tmp.appendingPathComponent("evil.exe"); try Data().write(to: f)
        XCTAssertThrowsError(try mm.importMod(from: f, games: [.zeroHour]))
        try fakeBig(tmp, "bad.big", magic: "NOPE")
        XCTAssertThrowsError(try mm.importMod(from: tmp.appendingPathComponent("bad.big"), games: [.zeroHour]))
        XCTAssertTrue(mm.mods.isEmpty)
    }
    func testModRemoveCreatesBackup() throws {
        let mm = ModManager(root: tmp.appendingPathComponent("mods"))
        try fakeBig(tmp, "ModA.big")
        let a = try mm.importMod(from: tmp.appendingPathComponent("ModA.big"), games: [.zeroHour])
        let backups = tmp.appendingPathComponent("backups")
        try mm.remove(a.id, backupDir: backups)
        XCTAssertTrue(mm.mods.isEmpty)
        XCTAssertEqual(BackupManager(root: backups).list().count, 1)
    }

    // MARK: Backups
    func testBackupAndRestore() throws {
        let f = tmp.appendingPathComponent("cfg/Options.ini")
        try FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("Resolution = 800 600".utf8).write(to: f)
        let bm = BackupManager(root: tmp.appendingPathComponent("b"))
        let z = try bm.backup(items: [f.deletingLastPathComponent()], label: "cfg")
        try Data("changed".utf8).write(to: f)
        _ = try bm.restore(z)
        XCTAssertEqual(try String(contentsOf: f, encoding: .utf8), "Resolution = 800 600")
        XCTAssertEqual(bm.list().count, 2) // original + pre-restore
    }

    func testExtraArgumentsParsing() {
        XCTAssertEqual(ExtraArguments.parse("  -a  \"b c\" d"), ["-a", "b c", "d"])
    }

    // MARK: Steam download
    func testSteamAccountValidation() {
        XCTAssertTrue(SteamDownloader.isValidAccountName("omar_123"))
        XCTAssertFalse(SteamDownloader.isValidAccountName("YOUR_USERNAME"))
        XCTAssertFalse(SteamDownloader.isValidAccountName(""))
        XCTAssertFalse(SteamDownloader.isValidAccountName("a b"))
        XCTAssertFalse(SteamDownloader.isValidAccountName("x; rm -rf ~"))
        XCTAssertFalse(SteamDownloader.isValidAccountName("عمر"))
        XCTAssertFalse(SteamDownloader.isValidAccountName("$(whoami)"))
    }
    func testSteamScriptWithExistingSteamCMD() throws {
        let s = try SteamDownloader.script(account: "omar123", games: [.zeroHour, .generals], toolsDir: tmp,
                                           existingSteamCMD: URL(fileURLWithPath: "/opt/homebrew/bin/steamcmd"),
                                           installDir: { URL(fileURLWithPath: "/Users/x/Games/\($0.rawValue)") })
        XCTAssertTrue(s.contains("STEAMCMD='/opt/homebrew/bin/steamcmd'"))
        XCTAssertTrue(s.contains("+@sSteamCmdForcePlatformType windows +force_install_dir '/Users/x/Games/zeroHour' +login omar123 +app_update 2732960 validate +force_install_dir '/Users/x/Games/generals' +app_update 2229870 validate +quit"))
        XCTAssertFalse(s.contains("curl"))
        XCTAssertEqual(s.components(separatedBy: "+login").count, 2) // logs in once
    }
    func testSteamScriptDownloadsOfficialSteamCMDWhenMissing() throws {
        let s = try SteamDownloader.script(account: "omar123", games: [.zeroHour], toolsDir: tmp, existingSteamCMD: nil)
        XCTAssertTrue(s.contains("curl -fsSL --proto '=https' 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz'"))
        XCTAssertTrue(s.contains("steamcmd/steamcmd.sh"))
    }
    func testSteamScriptRejectsBadInput() {
        XCTAssertThrowsError(try SteamDownloader.script(account: "a;b", games: [.zeroHour], toolsDir: tmp, existingSteamCMD: nil))
        XCTAssertThrowsError(try SteamDownloader.script(account: "ok", games: [], toolsDir: tmp, existingSteamCMD: nil))
    }
    func testWriteScriptIsPrivateAndExecutable() throws {
        let u = try SteamDownloader.writeScript("#!/bin/bash\n", cacheDir: tmp)
        let perms = try FileManager.default.attributesOfItem(atPath: u.path)[.posixPermissions] as? Int
        XCTAssertEqual(perms, 0o700)
    }
    func testZeroHourUsesBundledZHGenerals() throws {
        let zh = tmp.appendingPathComponent("zh"); for f in GameKind.zeroHour.requiredArchives { try fakeBig(zh, f) }
        let bundled = zh.appendingPathComponent("ZH_Generals"); for f in GameKind.generals.requiredArchives { try fakeBig(bundled, f) }
        let other = tmp.appendingPathComponent("gen"); for f in GameKind.generals.requiredArchives { try fakeBig(other, f) }
        var s = LauncherSettings(); s.zeroHour.installPath = zh.path; s.generals.installPath = other.path
        let p = try LaunchPlanner.plan(game: .zeroHour, settings: s, engine: makeEngine(), mods: [], paths: AppPaths(root: tmp))
        XCTAssertEqual(p.arguments[2...3], ["-generalsAssetPath", bundled.path])
    }

    func testGeneratedSteamScriptsPassBashSyntaxCheck() throws {
        for existing in [URL(fileURLWithPath: "/opt/homebrew/bin/steamcmd"), nil] {
            let body = try SteamDownloader.script(account: "omar_123", games: [.zeroHour, .generals],
                                                  toolsDir: tmp.appendingPathComponent("Tools with space"), existingSteamCMD: existing)
            let u = try SteamDownloader.writeScript(body, cacheDir: tmp)
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/bash"); p.arguments = ["-n", u.path]
            try p.run(); p.waitUntilExit()
            XCTAssertEqual(p.terminationStatus, 0)
        }
    }

    func testEngineInspectFindsAppBundle() throws {
        let app = tmp.appendingPathComponent("NOVEXA ZH.app/Contents")
        try FileManager.default.createDirectory(at: app.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Resources"), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: app.appendingPathComponent("MacOS/GeneralsXZH"))
        try Data("GeneralsX test".utf8).write(to: app.appendingPathComponent("Resources/ENGINE_VERSION"))
        let e = try XCTUnwrap(EngineLocator.inspect(directory: tmp, game: .zeroHour))
        XCTAssertEqual(e.binary.path, app.appendingPathComponent("MacOS/GeneralsXZH").path)
        XCTAssertEqual(e.resources.path, app.appendingPathComponent("Resources").path)
        XCTAssertEqual(e.version, "GeneralsX test")
    }
    func testPlanUsesBundleResourcesForConfig() throws {
        let zh = tmp.appendingPathComponent("zh"); for f in GameKind.zeroHour.requiredArchives { try fakeBig(zh, f) }
        var s = LauncherSettings(); s.zeroHour.installPath = zh.path
        var e = makeEngine(); e.resourcesDirectory = tmp.appendingPathComponent("Res")
        let p = try LaunchPlanner.plan(game: .zeroHour, settings: s, engine: e, mods: [], paths: AppPaths(root: tmp))
        XCTAssertEqual(p.environment["VK_ICD_FILENAMES"], tmp.appendingPathComponent("Res/MoltenVK_icd.json").path)
        XCTAssertEqual(p.environment["DYLD_LIBRARY_PATH"], tmp.path)
    }

    /// Integration: uses the real staged engine and the developer's own installed .ico when present.
    func testPersonalizerWithRealEngineAndIcon() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let runtime = root.appendingPathComponent("build/runtime/zeroHour")
        let install = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Games/ZeroHour").path
        guard let stock = EngineLocator.inspect(directory: runtime, game: .zeroHour), stock.isUsable,
              EnginePersonalizer.iconSource(.zeroHour, installPath: install) != nil else {
            throw XCTSkip("needs staged engine and ~/Games/ZeroHour")
        }
        let paths = AppPaths(root: tmp)
        let e = try XCTUnwrap(EnginePersonalizer.personalized(engine: stock, game: .zeroHour, installPath: install, paths: paths))
        XCTAssertTrue(e.binary.path.hasPrefix(tmp.path))
        XCTAssertTrue(e.isUsable)
        let app = e.directory.deletingLastPathComponent().deletingLastPathComponent()
        let icns = app.appendingPathComponent("Contents/Resources/AppIcon.icns")
        XCTAssertNotEqual(try Data(contentsOf: icns), try Data(contentsOf: stock.resources.appendingPathComponent("AppIcon.icns")))
        let v = Process(); v.executableURL = URL(fileURLWithPath: "/usr/bin/codesign"); v.arguments = ["--verify", "--deep", app.path]
        try v.run(); v.waitUntilExit()
        XCTAssertEqual(v.terminationStatus, 0, "personalized copy must have a valid signature")
        // Second call reuses the copy (stamp unchanged).
        let mtime = try FileManager.default.attributesOfItem(atPath: icns.path)[.modificationDate] as? Date
        _ = EnginePersonalizer.personalized(engine: stock, game: .zeroHour, installPath: install, paths: paths)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: icns.path)[.modificationDate] as? Date, mtime)
    }
    func testPersonalizerSkipsWithoutIcon() {
        let e = makeEngine()
        XCTAssertNil(EnginePersonalizer.personalized(engine: e, game: .zeroHour, installPath: tmp.path, paths: AppPaths(root: tmp)))
    }

    // MARK: Graphics
    func testIniMergeFlatReplacesAndAppends() {
        let out = IniMerge.mergeFlat("CampaignDifficulty = 0\nantialiasing = 0\n", [("AntiAliasing", "4"), ("FPSLimit", "yes")])
        XCTAssertEqual(out, "CampaignDifficulty = 0\nAntiAliasing = 4\nFPSLimit = yes\n")
    }
    func testIniMergeBlockKeepsCommentsAndOtherKeys() {
        let src = "; comment\nGameData\n  MaxCameraHeight = 350.0\n  ; note = keep\n  FramesPerSecondLimit = 60\nEnd\n"
        let out = IniMerge.mergeBlock(src, block: "GameData", [("FramesPerSecondLimit", "120"), ("UseFPSLimit", "Yes")])
        XCTAssertEqual(out, "; comment\nGameData\n  MaxCameraHeight = 350.0\n  ; note = keep\n  FramesPerSecondLimit = 120\n  UseFPSLimit = Yes\nEnd\n")
        XCTAssertEqual(IniMerge.mergeBlock("", block: "GameData", [("A", "1")]), "GameData\n  A = 1\nEnd\n")
    }
    func testPresets() {
        XCTAssertEqual(GraphicsSettings.make(.balanced).fpsLimit, 60)
        XCTAssertEqual(GraphicsSettings.make(.ultra).antiAliasing, 8)
        XCTAssertTrue(GraphicsSettings.make(.ultra).bloom)
        let unc = { var g = GraphicsSettings(); g.fpsLimit = 0; return g }()
        XCTAssertEqual(unc.sagePatchEntries.first?.1, "No")
        XCTAssertTrue(unc.optionsEntries(width: 1, height: 1).contains { $0 == ("FPSLimit", "no") })
    }
    func testGraphicsApplyWritesAndBacksUpOnlyOnChange() throws {
        let dir = tmp.appendingPathComponent("GeneralsZH")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "CampaignDifficulty = 0\n".write(to: dir.appendingPathComponent("Options.ini"), atomically: true, encoding: .utf8)
        let bm = BackupManager(root: tmp.appendingPathComponent("b"))
        let g = GraphicsSettings.make(.ultra)
        XCTAssertTrue(try GraphicsConfigWriter.apply(g, game: .zeroHour, width: 3024, height: 1964, userDir: dir, backups: bm))
        let opts = try String(contentsOf: dir.appendingPathComponent("Options.ini"), encoding: .utf8)
        XCTAssertTrue(opts.contains("CampaignDifficulty = 0"))
        XCTAssertTrue(opts.contains("Resolution = 3024 1964"))
        XCTAssertTrue(opts.contains("AntiAliasing = 8"))
        let sage = try String(contentsOf: dir.appendingPathComponent("SagePatch.ini"), encoding: .utf8)
        XCTAssertTrue(sage.contains("FramesPerSecondLimit = 120"))
        XCTAssertEqual(bm.list().count, 1)
        // Same settings again: nothing written, no new backup.
        XCTAssertFalse(try GraphicsConfigWriter.apply(g, game: .zeroHour, width: 3024, height: 1964, userDir: dir, backups: bm))
        XCTAssertEqual(bm.list().count, 1)
    }
    func testOldSettingsWithoutGraphicsStillDecode() throws {
        let json = #"{"zeroHour":{"displayMode":"windowed","width":1600,"height":900,"extraArguments":""},"generals":{"displayMode":"windowed","width":1600,"height":900,"extraArguments":""},"muted":false,"musicVolume":0.7,"sfxVolume":0.8,"voiceVolume":0.8}"#
        let u = tmp.appendingPathComponent("s.json"); try Data(json.utf8).write(to: u)
        let s = SettingsStore(url: u).load()
        XCTAssertNil(s.zeroHour.graphics)
        XCTAssertEqual(s.zeroHour.width, 1600)
    }

    func testPerformanceHUDEnv() throws {
        let zh = tmp.appendingPathComponent("zh"); for f in GameKind.zeroHour.requiredArchives { try fakeBig(zh, f) }
        var s = LauncherSettings(); s.zeroHour.installPath = zh.path
        XCTAssertNil(try LaunchPlanner.plan(game: .zeroHour, settings: s, engine: makeEngine(), mods: [], paths: AppPaths(root: tmp)).environment["MTL_HUD_ENABLED"])
        s.zeroHour.showPerformanceHUD = true
        XCTAssertEqual(try LaunchPlanner.plan(game: .zeroHour, settings: s, engine: makeEngine(), mods: [], paths: AppPaths(root: tmp)).environment["MTL_HUD_ENABLED"], "1")
    }

    // MARK: Online
    func testOnlineEnvironment() throws {
        var o = OnlineSettings()
        XCTAssertEqual(o.environment, ["NGMP_SERVER_HOST": "play.novexa-jo.com", "NGMP_SERVER_PORT": "443", "NGMP_SERVER_SSL": "1"])
        o.mode = .thisMac
        XCTAssertEqual(o.environment, ["NGMP_SERVER_HOST": "127.0.0.1", "NGMP_SERVER_PORT": "9001", "NGMP_SERVER_SSL": "0"])
        o.mode = .official
        XCTAssertEqual(o.environment["NGMP_SERVER_SSL"], "1")
        o.mode = .custom; o.host = "http://evil.com/x"; XCTAssertTrue(o.environment.isEmpty)
        o.host = "play.example.com"; o.port = 9001
        XCTAssertEqual(o.environment["NGMP_SERVER_HOST"], "play.example.com")
    }

    func testEngineWritesStayOutOfBundle() throws {
        let zh = tmp.appendingPathComponent("zh"); for f in GameKind.zeroHour.requiredArchives { try fakeBig(zh, f) }
        var s = LauncherSettings(); s.zeroHour.installPath = zh.path
        let paths = AppPaths(root: tmp.appendingPathComponent("support"))
        let p = try LaunchPlanner.plan(game: .zeroHour, settings: s, engine: makeEngine(), mods: [], paths: paths)
        for v in [p.workingDirectory.path, p.environment["DXVK_STATE_CACHE_PATH"]!, p.environment["DXVK_LOG_PATH"]!, p.environment["XDG_CACHE_HOME"]!] {
            XCTAssertTrue(v.hasPrefix(paths.root.path), v)
        }
    }

    func testLaunchAlwaysUsesNovexaUnlessDevOverride() throws {
        XCTAssertEqual(OnlineSettings.effective([:]).environment["NGMP_SERVER_HOST"], "play.novexa-jo.com")
        XCTAssertEqual(OnlineSettings.effective(["NOVEXA_DEV_SERVER": "127.0.0.1:9001"]).environment,
                       ["NGMP_SERVER_HOST": "127.0.0.1", "NGMP_SERVER_PORT": "9001", "NGMP_SERVER_SSL": "0"])
        XCTAssertEqual(OnlineSettings.effective(["NOVEXA_DEV_SERVER": "bad host!:1"]).environment["NGMP_SERVER_HOST"], "play.novexa-jo.com")
        // An old saved "custom" choice must not change where players connect.
        let zh = tmp.appendingPathComponent("zh"); for f in GameKind.zeroHour.requiredArchives { try fakeBig(zh, f) }
        var s = LauncherSettings(); s.zeroHour.installPath = zh.path
        var old = OnlineSettings(); old.mode = .custom; old.host = "evil.example.com"; s.online = old
        let p = try LaunchPlanner.plan(game: .zeroHour, settings: s, engine: makeEngine(), mods: [], paths: AppPaths(root: tmp))
        if ProcessInfo.processInfo.environment["NOVEXA_DEV_SERVER"] == nil {
            XCTAssertEqual(p.environment["NGMP_SERVER_HOST"], "play.novexa-jo.com")
        }
    }

    // MARK: Settings robustness
    func testUnknownValuesDoNotWipeSettings() throws {
        let json = #"{"zeroHour":{"installPath":"/z","displayMode":"borderless-from-the-future","width":2560,"height":1440,"extraArguments":""},"generals":{"installPath":"/g"},"online":{"mode":"someNewMode","host":"x","port":1,"ssl":true},"lastPlayed":"zeroHour","futureKey":42}"#
        let u = tmp.appendingPathComponent("settings.json"); try Data(json.utf8).write(to: u)
        let s = SettingsStore(url: u).load()
        XCTAssertEqual(s.zeroHour.installPath, "/z")
        XCTAssertEqual(s.generals.installPath, "/g")
        XCTAssertEqual(s.zeroHour.displayMode, .windowed)   // unknown enum -> default, rest kept
        XCTAssertEqual(s.zeroHour.width, 2560)
        XCTAssertNil(s.online)                                // unknown online mode -> ignored
        XCTAssertEqual(s.lastPlayed, .zeroHour)
        XCTAssertEqual(s.musicVolume, 0.7)                    // missing -> default
    }
    func testUnreadableSettingsAreKeptNotOverwritten() throws {
        let u = tmp.appendingPathComponent("settings.json"); try Data("[1,2,3]".utf8).write(to: u)
        _ = SettingsStore(url: u).load()
        let kept = try FileManager.default.contentsOfDirectory(atPath: tmp.path).filter { $0.hasPrefix("settings.unreadable-") }
        XCTAssertEqual(kept.count, 1)
    }
    func testDiscoverSteamDownloadLocation() throws {
        for f in GameKind.zeroHour.requiredArchives { try fakeBig(tmp.appendingPathComponent("Games/ZeroHour"), f) }
        for f in GameKind.generals.requiredArchives { try fakeBig(tmp.appendingPathComponent("Games/Generals"), f) }
        XCTAssertEqual(InstallationValidator.discover(game: .zeroHour, home: tmp).first?.lastPathComponent, "ZeroHour")
        XCTAssertEqual(InstallationValidator.discover(game: .generals, home: tmp).first?.lastPathComponent, "Generals")
    }
}
