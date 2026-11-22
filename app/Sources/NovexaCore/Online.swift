import Foundation

/// Which GeneralsOnline (NGMP) server the game talks to. Passed to the engine at launch through
/// NGMP_SERVER_HOST / NGMP_SERVER_PORT / NGMP_SERVER_SSL (NOVEXA engine patch 0001).
public struct OnlineSettings: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, CaseIterable, Sendable, Identifiable {
        case novexa, thisMac, custom, official
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .novexa: return "NOVEXA Online"
            case .thisMac: return "This Mac"
            case .custom: return "Private server"
            case .official: return "Official GeneralsX"
            }
        }
    }
    public var mode: Mode = .novexa
    public var host: String = ""
    public var port: Int = 9001
    public var ssl: Bool = false
    public init() {}

    public static let officialHost = "online.generalsx.org"
    /// NOVEXA's own GeneralsOnline server (Windows VPS behind Cloudflare, Discord login).
    public static let novexaHost = "play.novexa-jo.com"

    /// Hostnames / IPv4 / bracket-less IPv6 only — no scheme, path or spaces.
    public static func isValidHost(_ h: String) -> Bool {
        guard (1...253).contains(h.count) else { return false }
        return h.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) && $0.isASCII || ".-:".unicodeScalars.contains($0) }
    }

    public var resolved: (host: String, port: Int, ssl: Bool)? {
        switch mode {
        case .novexa: return (Self.novexaHost, 443, true)
        case .thisMac: return ("127.0.0.1", 9001, false)
        case .official: return (Self.officialHost, 443, true)
        case .custom:
            guard Self.isValidHost(host), (1...65535).contains(port) else { return nil }
            return (host, port, ssl)
        }
    }

    /// The server every launch uses: NOVEXA Online. Developers can point a build elsewhere with the
    /// hidden environment variable NOVEXA_DEV_SERVER="host:port[:ssl]" (e.g. 127.0.0.1:9001 or
    /// staging.example.com:443:ssl). It is never exposed in the UI.
    public static func effective(_ env: [String: String] = ProcessInfo.processInfo.environment) -> OnlineSettings {
        var o = OnlineSettings()
        if let dev = env["NOVEXA_DEV_SERVER"], !dev.isEmpty {
            let parts = dev.split(separator: ":").map(String.init)
            if parts.count >= 2, isValidHost(parts[0]), let port = Int(parts[1]) {
                o.mode = .custom; o.host = parts[0]; o.port = port; o.ssl = parts.count > 2 && parts[2] == "ssl"
            }
        }
        return o
    }

    public var environment: [String: String] {
        guard let r = resolved else { return [:] }
        return ["NGMP_SERVER_HOST": r.host, "NGMP_SERVER_PORT": String(r.port), "NGMP_SERVER_SSL": r.ssl ? "1" : "0"]
    }
}

public enum LocalNetwork {
    /// The Mac's private IPv4 addresses (for telling LAN friends where the server is).
    public static func ipv4Addresses() -> [String] {
        var out: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }
        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let sa = p.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: p.pointee.ifa_name)
            guard name.hasPrefix("en") else { continue }
            var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &buf, socklen_t(buf.count), nil, 0, NI_NUMERICHOST) == 0 {
                out.append(String(cString: buf))
            }
        }
        return out
    }
}
