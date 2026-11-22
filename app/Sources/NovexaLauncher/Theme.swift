import SwiftUI
import AppKit
import CoreText

/// Design tokens mirroring novexa-jo.com (dark variant): ink surfaces, porcelain text,
/// the ultra → magenta → ember brand gradient, Alexandria / Instrument Sans / IBM Plex Mono.
enum Theme {
    static let ink = Color(hex: 0x0B0A14)
    static let surface = Color(hex: 0x13111F)
    static let surface2 = Color(hex: 0x1A1729)
    static let line = Color(hex: 0x25213A)
    static let edge = Color(hex: 0x3A3550)
    static let text = Color(hex: 0xECEAF5)
    static let mute = Color(hex: 0xABA7C0)
    static let eyebrow = Color(hex: 0x8A85A3)
    static let titanium = Color(hex: 0x9A96AE)
    static let ultra = Color(hex: 0x7C3AED)
    static let magenta = Color(hex: 0xEC4899)
    static let ember = Color(hex: 0xFB923C)
    static let ok = Color(hex: 0x34D399)
    static let warn = Color(hex: 0xFBBF24)
    static let bad = Color(hex: 0xF87171)

    static let gradient = LinearGradient(stops: [.init(color: ultra, location: 0), .init(color: magenta, location: 0.55),
                                                 .init(color: ember, location: 1)],
                                         startPoint: .bottomLeading, endPoint: .topTrailing)
    static let r: CGFloat = 14, rLg: CGFloat = 22, rSm: CGFloat = 8

    // Legacy aliases used across views
    static var panel: Color { surface }
    static var dim: Color { mute }
    static var accent: Color { magenta }
    static var bg: Color { ink }
    static var mono: Font { Fonts.mono(11) }
}

enum Fonts {
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font { .custom("Alexandria", size: size).weight(weight) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .custom("Instrument Sans", size: size).weight(weight) }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .custom("IBM Plex Mono", size: size).weight(weight) }

    /// Registers bundled OFL fonts (app bundle Resources/Fonts, or the source tree during `swift run`).
    static func register() {
        var dirs: [URL] = []
        if let r = Bundle.main.resourceURL { dirs.append(r.appendingPathComponent("Fonts")) }
        dirs.append(URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Resources/Fonts"))
        for d in dirs {
            let files = (try? FileManager.default.contentsOfDirectory(at: d, includingPropertiesForKeys: nil)) ?? []
            let ttfs = files.filter { $0.pathExtension == "ttf" }
            guard !ttfs.isEmpty else { continue }
            for f in ttfs { CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil) }
            return
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

/// Ink backdrop with the site's soft ultra / ember radial glows.
struct Backdrop: View {
    var body: some View {
        ZStack {
            Theme.ink
            RadialGradient(colors: [Theme.ultra.opacity(0.20), .clear], center: .topTrailing, startRadius: 0, endRadius: 700)
            RadialGradient(colors: [Theme.ember.opacity(0.08), .clear], center: .bottomLeading, startRadius: 0, endRadius: 600)
        }.ignoresSafeArea()
    }
}

/// "── NOVEXA · SECTION" eyebrow label.
struct Eyebrow: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.edge).frame(width: 28, height: 1)
            Text(text.uppercased()).font(Fonts.mono(11, .medium)).tracking(1.4).foregroundStyle(Theme.eyebrow)
        }.accessibilityElement(children: .combine)
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased()).font(Fonts.mono(11, .medium)).tracking(1.4).foregroundStyle(Theme.eyebrow)
    }
}

/// Text filled with the brand gradient.
struct GradientText: View {
    let text: String; let font: Font
    var body: some View {
        Text(text).font(font).foregroundStyle(Theme.gradient)
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: Theme.r, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.r, style: .continuous).strokeBorder(Theme.line))
    }
}
typealias Panel = CardDefault
struct CardDefault<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { Card { content } }
}

struct StatusDot: View {
    let color: Color
    var body: some View {
        Circle().fill(color).frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.7), radius: 4).accessibilityHidden(true)
    }
}

/// Pill status chip: ● LABEL
struct StatusChip: View {
    let text: String; let color: Color
    var body: some View {
        HStack(spacing: 7) {
            StatusDot(color: color)
            Text(text.uppercased()).font(Fonts.mono(10, .medium)).tracking(1).foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
        .environment(\.colorScheme, .dark)
    }
}

struct KeyValueRow: View {
    let key: String; let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key).font(Fonts.body(12)).foregroundStyle(Theme.mute).frame(width: 180, alignment: .leading)
            Text(value).font(Fonts.mono(12)).foregroundStyle(Theme.text).textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line.opacity(0.6)).frame(height: 1) }
    }
}

/// Primary: gradient pill (site CTA).
struct PrimaryButtonStyle: ButtonStyle {
    var large = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Fonts.body(large ? 15 : 13, .semibold))
            .lineLimit(1).fixedSize()
            .padding(.horizontal, large ? 26 : 18).padding(.vertical, large ? 12 : 8)
            .foregroundStyle(.white)
            .background(Theme.gradient, in: Capsule())
            .shadow(color: Theme.magenta.opacity(configuration.isPressed ? 0.15 : 0.35), radius: 14, y: 6)
            .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Secondary: outlined pill.
struct GhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Fonts.body(13, .medium))
            .lineLimit(1).fixedSize()
            .padding(.horizontal, 16).padding(.vertical, 8)
            .foregroundStyle(Theme.text)
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.03), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.edge))
            .opacity(enabled ? 1 : 0.4)
    }
}

/// Danger: used for STOP.
struct StopButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Fonts.body(13, .semibold))
            .padding(.horizontal, 18).padding(.vertical, 8)
            .foregroundStyle(.white)
            .background(Theme.bad.opacity(configuration.isPressed ? 0.7 : 0.9), in: Capsule())
    }
}
