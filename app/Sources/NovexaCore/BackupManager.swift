import Foundation

public struct BackupRecord: Identifiable, Equatable, Sendable {
    public var id: String { url.lastPathComponent }
    public var url: URL
    public var date: Date
    public var size: Int64
}

/// Zip backups via the system `ditto` tool; restores never overwrite without first backing up the target.
public struct BackupManager: Sendable {
    public let root: URL
    public init(root: URL) { self.root = root }

    @discardableResult
    public func backup(items: [URL], label: String) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let staging = fm.temporaryDirectory.appendingPathComponent("novexa-backup-\(UUID().uuidString)")
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        var manifest: [String: String] = [:]
        for (n, item) in items.enumerated() where fm.fileExists(atPath: item.path) {
            let name = "\(n)-" + item.lastPathComponent
            try fm.copyItem(at: item, to: staging.appendingPathComponent(name))
            manifest[name] = item.path
        }
        try JSONEncoder.novexa.encode(manifest).write(to: staging.appendingPathComponent("manifest.json"))
        let out = root.appendingPathComponent("\(PathSecurity.sanitizedName(label))-\(stamp).zip")
        try run(["-c", "-k", "--sequesterRsrc", staging.path, out.path])
        return out
    }

    public func list() -> [BackupRecord] {
        let items = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? []
        return items.filter { $0.pathExtension == "zip" }.map {
            let v = try? $0.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            return BackupRecord(url: $0, date: v?.contentModificationDate ?? .distantPast, size: Int64(v?.fileSize ?? 0))
        }.sorted { $0.date > $1.date }
    }

    /// Restores every item in the backup to its original location. Existing targets are
    /// backed up first (label "pre-restore") so a restore can itself be undone.
    public func restore(_ backup: URL) throws -> [URL] {
        let fm = FileManager.default
        let staging = fm.temporaryDirectory.appendingPathComponent("novexa-restore-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: staging) }
        try run(["-x", "-k", backup.path, staging.path])
        let manifest = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: staging.appendingPathComponent("manifest.json")))
        let targets = manifest.values.map { URL(fileURLWithPath: $0) }
        let existing = targets.filter { fm.fileExists(atPath: $0.path) }
        if !existing.isEmpty { try self.backup(items: existing, label: "pre-restore") }
        for (name, original) in manifest {
            let src = try PathSecurity.safeJoin(root: staging, relative: name)
            let dst = URL(fileURLWithPath: original)
            if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
            try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: src, to: dst)
        }
        return targets
    }

    private func run(_ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto"); p.arguments = args
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw ModError.io("ditto failed (\(p.terminationStatus))") }
    }
}
