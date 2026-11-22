import Foundation

/// Downloads the user's OWN Steam copy of a game with Valve's official SteamCMD.
///
/// The launcher never sees the Steam password or Steam Guard code: it writes a small
/// `.command` script and opens it in Terminal, where the user types them into SteamCMD
/// directly. The launcher then watches the install folder and links it when complete.
public enum SteamDownloader {
    /// Steam store app IDs (verified against store.steampowered.com/api/appdetails, 2026-11-22).
    public static func appID(_ game: GameKind) -> Int {
        switch game {
        case .generals: return 2229870
        case .zeroHour: return 2732960
        }
    }

    /// Valve's official macOS SteamCMD archive (used only when SteamCMD is not installed).
    public static let officialSteamCMDURL = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz"

    public static func defaultInstallDir(_ game: GameKind, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Games/\(game == .zeroHour ? "ZeroHour" : "Generals")", isDirectory: true)
    }

    /// Steam account names are 3–64 chars of letters, digits and underscore. Anything else is
    /// rejected, which also guarantees the name is safe to place in a shell script.
    public static func isValidAccountName(_ s: String) -> Bool {
        guard (1...64).contains(s.count), s != "YOUR_USERNAME" else { return false }
        return s.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) && $0.isASCII || $0 == "_" }
    }

    /// Finds an existing steamcmd (Homebrew, or a previous launcher-managed install).
    public static func locateSteamCMD(toolsDir: URL) -> URL? {
        let candidates = ["/opt/homebrew/bin/steamcmd", "/usr/local/bin/steamcmd",
                          toolsDir.appendingPathComponent("steamcmd/steamcmd.sh").path]
        return candidates.map(URL.init(fileURLWithPath:)).first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static func shellQuote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    /// Builds the Terminal script. Pure function, unit-tested.
    public static func script(account: String, games: [GameKind], toolsDir: URL, existingSteamCMD: URL?,
                              installDir: (GameKind) -> URL = { defaultInstallDir($0) }) throws -> String {
        guard isValidAccountName(account) else { throw ModError.unsupported("invalid Steam account name") }
        guard !games.isEmpty else { throw ModError.unsupported("no game selected") }
        let steamDir = toolsDir.appendingPathComponent("steamcmd")
        var s = """
        #!/bin/bash
        # NOVEXA Generals Mac — download your own Steam copy with Valve SteamCMD.
        # Your password and Steam Guard code are typed into SteamCMD only; NOVEXA never sees them.
        set -e
        clear
        echo "NOVEXA Generals Mac — Steam download"
        echo "Account: \(account)"
        echo

        """
        if let existing = existingSteamCMD {
            s += "STEAMCMD=\(shellQuote(existing.path))\n"
        } else {
            s += """
            echo "SteamCMD not found. Downloading Valve's official SteamCMD..."
            mkdir -p \(shellQuote(steamDir.path))
            curl -fsSL --proto '=https' \(shellQuote(officialSteamCMDURL)) | tar -xz -C \(shellQuote(steamDir.path))
            STEAMCMD=\(shellQuote(steamDir.appendingPathComponent("steamcmd.sh").path))

            """
        }
        s += "\"$STEAMCMD\" +@sSteamCmdForcePlatformType windows"
        for (i, g) in games.enumerated() {
            s += " +force_install_dir \(shellQuote(installDir(g).path))"
            if i == 0 { s += " +login \(account)" }
            s += " +app_update \(appID(g)) validate"
        }
        s += " +quit\n"
        s += """
        echo
        echo "Download finished. Return to NOVEXA Generals Mac — it will detect the game automatically."
        echo "You can close this window."

        """
        return s
    }

    /// Writes the script to `cacheDir` and returns its URL (opened by the UI in Terminal).
    public static func writeScript(_ contents: String, cacheDir: URL) throws -> URL {
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let url = cacheDir.appendingPathComponent("novexa-steam-download.command")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }
}
