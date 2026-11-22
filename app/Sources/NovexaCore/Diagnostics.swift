import Foundation

public struct DiagnosticsReport: Sendable {
    public var entries: [(String, String)]
    public var text: String { entries.map { "\($0.0): \($0.1)" }.joined(separator: "\n") }
}

public enum Diagnostics {
    public static let launcherVersion = "0.1.2"

    static func sysctl(_ name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buf, &size, nil, 0)
        return String(cString: buf)
    }

    public static func collect(settings: LauncherSettings, paths: AppPaths) -> DiagnosticsReport {
        let pi = ProcessInfo.processInfo
        var e: [(String, String)] = []
        e.append(("macOS", pi.operatingSystemVersionString))
        e.append(("Model", sysctl("hw.model")))
        e.append(("CPU", sysctl("machdep.cpu.brand_string")))
        #if arch(arm64)
        e.append(("Launcher architecture", "arm64"))
        #else
        e.append(("Launcher architecture", "x86_64"))
        #endif
        e.append(("Memory", ByteCountFormatter.string(fromByteCount: Int64(pi.physicalMemory), countStyle: .memory)))
        e.append(("Launcher version", launcherVersion))
        e.append(("Graphics backend", "Direct3D 8 → DXVK (Vulkan) → MoltenVK (Metal)"))
        e.append(("Data folder", paths.root.path))
        for g in GameKind.allCases {
            let eng = EngineLocator.locate(game: g, paths: paths, override: settings.engineDirectory)
            e.append(("\(g.displayName) engine", eng.map { "\($0.binary.path) [\($0.architecture.rawValue)] \($0.version ?? "")" + ($0.missingComponents.isEmpty ? "" : " missing: \($0.missingComponents.joined(separator: ", "))") } ?? "not installed"))
            let r = InstallationValidator.validate(game: g, path: settings[g].installPath.map { URL(fileURLWithPath: $0) })
            e.append(("\(g.displayName) data", "\(settings[g].installPath ?? "-") — \(r.summary)"))
        }
        return DiagnosticsReport(entries: e)
    }

    /// Writes diagnostics plus the most recent logs into a zip for sharing.
    public static func exportLogs(settings: LauncherSettings, paths: AppPaths, to dest: URL) throws {
        let fm = FileManager.default
        let staging = fm.temporaryDirectory.appendingPathComponent("novexa-logs-\(UUID().uuidString)")
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        try collect(settings: settings, paths: paths).text.write(to: staging.appendingPathComponent("diagnostics.txt"), atomically: true, encoding: .utf8)
        let logs = ((try? fm.contentsOfDirectory(at: paths.logsDir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .sorted { $0.lastPathComponent > $1.lastPathComponent }.prefix(10)
        for l in logs { try? fm.copyItem(at: l, to: staging.appendingPathComponent(l.lastPathComponent)) }
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = ["-c", "-k", staging.path, dest.path]; try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw ModError.io("log export failed") }
    }
}
