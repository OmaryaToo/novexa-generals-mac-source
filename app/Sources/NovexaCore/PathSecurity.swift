import Foundation

public enum PathSecurityError: Error, Equatable, CustomStringConvertible {
    case escapesRoot(String)
    case invalidComponent(String)

    public var description: String {
        switch self {
        case .escapesRoot(let p): return "Path escapes its allowed directory: \(p)"
        case .invalidComponent(let c): return "Invalid path component: \(c)"
        }
    }
}

public enum PathSecurity {
    /// Joins a relative path (e.g. from an archive entry) to `root`, rejecting
    /// absolute paths, `..` traversal and symlink escapes.
    public static func safeJoin(root: URL, relative: String) throws -> URL {
        if relative.hasPrefix("/") || relative.hasPrefix("~") { throw PathSecurityError.escapesRoot(relative) }
        let parts = relative.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        for p in parts where p == ".." || p.contains("\0") || p.contains("\\") {
            throw PathSecurityError.invalidComponent(p)
        }
        var url = root
        for p in parts where p != "." { url.appendPathComponent(p) }
        guard isInside(url, root: root) else { throw PathSecurityError.escapesRoot(relative) }
        return url
    }

    /// True when `url` (after resolving symlinks) is `root` or lies beneath it.
    public static func isInside(_ url: URL, root: URL) -> Bool {
        let r = root.standardizedFileURL.resolvingSymlinksInPath().path
        let u = url.standardizedFileURL.resolvingSymlinksInPath().path
        return u == r || u.hasPrefix(r.hasSuffix("/") ? r : r + "/")
    }

    /// Sanitises a user-supplied name for use as a single directory name.
    public static func sanitizedName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_.()"))
        let cleaned = String(name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
            .trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        return cleaned.isEmpty ? "Unnamed" : String(cleaned.prefix(80))
    }
}
