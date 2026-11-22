import Foundation

public struct ModRecord: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var games: [GameKind]
    public var enabled: Bool
    public var importedAt: Date
    /// File (.big) or directory passed to the engine via `-mod`.
    public var contentPath: String
    /// Lowercased relative file names provided by the mod; used for conflict detection.
    public var files: [String]
}

public enum ModError: Error, CustomStringConvertible, Equatable {
    case unsupported(String), notFound(String), io(String)
    public var description: String {
        switch self {
        case .unsupported(let s): return "Unsupported mod: \(s)"
        case .notFound(let s): return "Mod not found: \(s)"
        case .io(let s): return s
        }
    }
}

/// Mods are copied into isolated folders under Application Support; original game files are never modified.
public final class ModManager: @unchecked Sendable {
    public let root: URL
    private var indexURL: URL { root.appendingPathComponent("mods.json") }
    public private(set) var mods: [ModRecord] = []

    public init(root: URL) {
        self.root = root
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if let d = try? Data(contentsOf: indexURL), let m = try? JSONDecoder.novexa.decode([ModRecord].self, from: d) { mods = m }
    }

    private func persist() throws { try JSONEncoder.novexa.encode(mods).write(to: indexURL, options: .atomic) }

    /// Imports a .big archive, a folder, or a .zip (extracted with /usr/bin/ditto, then traversal-checked).
    @discardableResult
    public func importMod(from source: URL, name: String? = nil, games: [GameKind]) throws -> ModRecord {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: source.path, isDirectory: &isDir) else { throw ModError.notFound(source.path) }
        let display = name ?? source.deletingPathExtension().lastPathComponent
        let id = UUID().uuidString
        let dest = root.appendingPathComponent(id, isDirectory: true)
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        do {
            let ext = source.pathExtension.lowercased()
            if isDir.boolValue {
                try fm.copyItem(at: source, to: dest.appendingPathComponent("content"))
            } else if ext == "big" {
                guard InstallationValidator.isBigArchive(source) else { throw ModError.unsupported("not a valid BIG archive") }
                try fm.createDirectory(at: dest.appendingPathComponent("content"), withIntermediateDirectories: true)
                try fm.copyItem(at: source, to: dest.appendingPathComponent("content/" + PathSecurity.sanitizedName(source.lastPathComponent)))
            } else if ext == "zip" {
                let content = dest.appendingPathComponent("content")
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                p.arguments = ["-x", "-k", "--norsrc", source.path, content.path]
                try p.run(); p.waitUntilExit()
                guard p.terminationStatus == 0 else { throw ModError.io("Could not extract archive") }
                try Self.assertContained(content)
            } else { throw ModError.unsupported(".\(ext) files (use .big, .zip or a folder)") }

            let content = dest.appendingPathComponent("content")
            let files = Self.listFiles(content)
            guard files.contains(where: { $0.hasSuffix(".big") || $0.hasSuffix(".ini") || $0.hasSuffix(".w3d") }) else {
                throw ModError.unsupported("no .big, .ini or .w3d files found")
            }
            let rec = ModRecord(id: id, name: PathSecurity.sanitizedName(display), games: games, enabled: true,
                                importedAt: Date(), contentPath: content.path, files: files)
            mods.append(rec); try persist()
            return rec
        } catch { try? fm.removeItem(at: dest); throw error }
    }

    /// Rejects symlinks pointing outside the mod folder (zip-slip protection).
    static func assertContained(_ dir: URL) throws {
        let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isSymbolicLinkKey])
        while let u = e?.nextObject() as? URL {
            if (try? u.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true,
               !PathSecurity.isInside(u.resolvingSymlinksInPath(), root: dir) {
                throw ModError.unsupported("archive contains a link outside its folder")
            }
        }
    }

    static func listFiles(_ dir: URL) -> [String] {
        let base = dir.standardizedFileURL.path
        var out: [String] = []
        let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey])
        while let u = e?.nextObject() as? URL {
            if (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                out.append(String(u.standardizedFileURL.path.dropFirst(base.count + 1)).lowercased())
            }
        }
        return out.sorted()
    }

    public func setEnabled(_ id: String, _ enabled: Bool) throws {
        guard let i = mods.firstIndex(where: { $0.id == id }) else { throw ModError.notFound(id) }
        mods[i].enabled = enabled; try persist()
    }

    /// Removes a mod after backing its folder up into `backupDir`.
    public func remove(_ id: String, backupDir: URL) throws {
        guard let i = mods.firstIndex(where: { $0.id == id }) else { throw ModError.notFound(id) }
        let folder = root.appendingPathComponent(id)
        try BackupManager(root: backupDir).backup(items: [folder], label: "mod-\(mods[i].name)")
        try FileManager.default.removeItem(at: folder)
        mods.remove(at: i); try persist()
    }

    /// Files shared by two or more enabled mods for the same game.
    public func conflicts(for game: GameKind) -> [String: [String]] {
        var owners: [String: [String]] = [:]
        for m in mods where m.enabled && m.games.contains(game) { for f in m.files { owners[f, default: []].append(m.name) } }
        return owners.filter { $0.value.count > 1 }
    }
}
