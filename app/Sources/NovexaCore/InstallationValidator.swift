import Foundation

public struct ValidationReport: Equatable, Sendable {
    public enum Status: Equatable, Sendable { case notConfigured, missingFolder, invalid, incomplete, valid }
    public var game: GameKind
    public var path: URL?
    public var status: Status
    public var missingRequired: [String]
    public var missingRecommended: [String]
    public var foundArchives: [String]
    public var invalidArchives: [String]

    public var isLaunchable: Bool { status == .valid || status == .incomplete }

    public var summary: String {
        switch status {
        case .notConfigured: return "No installation selected"
        case .missingFolder: return "Folder no longer exists"
        case .invalid: return "Missing required data: " + missingRequired.joined(separator: ", ")
        case .incomplete: return "Usable; missing optional: " + missingRecommended.joined(separator: ", ")
        case .valid: return "Installation verified (\(foundArchives.count) archives)"
        }
    }
}

public enum InstallationValidator {
    /// BIG archives start with the ASCII magic "BIGF" or "BIG4".
    public static func isBigArchive(_ url: URL) -> Bool {
        guard let h = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? h.close() }
        guard let d = try? h.read(upToCount: 4), d.count == 4 else { return false }
        return d == Data("BIGF".utf8) || d == Data("BIG4".utf8)
    }

    /// Case-insensitive file lookup (retail installs mix case).
    static func archiveIndex(in dir: URL) -> [String: URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        var map: [String: URL] = [:]
        for u in items where u.pathExtension.lowercased() == "big" { map[u.lastPathComponent.lowercased()] = u }
        return map
    }

    public static func validate(game: GameKind, path: URL?) -> ValidationReport {
        guard let path else {
            return .init(game: game, path: nil, status: .notConfigured, missingRequired: game.requiredArchives, missingRecommended: [], foundArchives: [], invalidArchives: [])
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path.path, isDirectory: &isDir), isDir.boolValue else {
            return .init(game: game, path: path, status: .missingFolder, missingRequired: game.requiredArchives, missingRecommended: [], foundArchives: [], invalidArchives: [])
        }
        let index = archiveIndex(in: path)
        let invalid = index.values.filter { !isBigArchive($0) }.map(\.lastPathComponent).sorted()
        let missingReq = game.requiredArchives.filter { index[$0.lowercased()] == nil }
        let missingRec = game.recommendedArchives.filter { index[$0.lowercased()] == nil }
        let status: ValidationReport.Status
        if !missingReq.isEmpty || invalid.contains(where: { n in game.requiredArchives.contains { $0.lowercased() == n.lowercased() } }) {
            status = .invalid
        } else if !missingRec.isEmpty || !invalid.isEmpty {
            status = .incomplete
        } else { status = .valid }
        return .init(game: game, path: path, status: status, missingRequired: missingReq, missingRecommended: missingRec,
                     foundArchives: index.values.map(\.lastPathComponent).sorted(), invalidArchives: invalid)
    }

    /// Candidate install folders in well-known locations under the user's home.
    /// Nothing is assumed: each candidate is only returned if it validates.
    public static func discover(game: GameKind, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        let rel: [String]
        switch game {
        case .generals: rel = ["GeneralsX/Generals", "Games/Generals",
            "Library/Application Support/Steam/steamapps/common/Command & Conquer Generals",
            "Library/Application Support/CrossOver/Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Command and Conquer Generals",
            "Library/Application Support/CrossOver/Bottles/EA App/drive_c/Program Files/EA Games/Command and Conquer Generals"]
        case .zeroHour: rel = ["GeneralsX/GeneralsZH", "GeneralsX/GeneralsMD", "Games/Zero Hour",
            "Library/Application Support/Steam/steamapps/common/Command & Conquer Generals - Zero Hour",
            "Library/Application Support/CrossOver/Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Command and Conquer Generals Zero Hour",
            "Library/Application Support/CrossOver/Bottles/EA App/drive_c/Program Files/EA Games/Command and Conquer Generals Zero Hour"]
        }
        return rel.map { home.appendingPathComponent($0, isDirectory: true) }
            .filter { validate(game: game, path: $0).isLaunchable }
    }
}
