import SwiftUI
import NovexaCore

enum Section: String, CaseIterable, Identifiable {
    case home = "Home", generals = "Generals", zeroHour = "Zero Hour", mods = "Mods", settings = "Settings", diagnostics = "Diagnostics", about = "About"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .home: return "house"
        case .generals: return "shield"
        case .zeroHour: return "shield.lefthalf.filled"
        case .mods: return "puzzlepiece.extension"
        case .settings: return "slider.horizontal.3"
        case .diagnostics: return "waveform.path.ecg"
        case .about: return "info.circle"
        }
    }
    var game: GameKind? { self == .generals ? .generals : self == .zeroHour ? .zeroHour : nil }
}

// MARK: - Shell

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @State private var section: Section = Section(rawValue: ProcessInfo.processInfo.environment["NOVEXA_SECTION"] ?? "") ?? .home

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(section: $section)
            Rectangle().fill(Theme.line).frame(width: 1)
            ScrollView {
                Group {
                    switch section {
                    case .home: HomeView(section: $section)
                    case .generals: GameView(game: .generals)
                    case .zeroHour: GameView(game: .zeroHour)
                    case .mods: ModsView()
                    case .settings: SettingsView()
                    case .diagnostics: DiagnosticsView()
                    case .about: AboutView()
                    }
                }
                .padding(.horizontal, 36).padding(.top, 44).padding(.bottom, 36)
                .frame(maxWidth: 1120, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(section)
                .transition(.opacity)
            }
            .scrollContentBackground(.hidden)
        }
        .background(Backdrop())
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
        .tint(Theme.magenta)
        .animation(.easeOut(duration: 0.18), value: section)
        .overlay(alignment: .bottom) { ErrorBanner() }
        .sheet(isPresented: $model.showSteamSheet) { SteamDownloadSheet() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if model.steamDownloadPending.isEmpty { model.refresh() } else { model.checkSteamDownloads() }
        }
    }
}

struct Sidebar: View {
    @EnvironmentObject var model: AppModel
    @Binding var section: Section

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                NovexaWordmark().frame(width: 118)
                Text("GENERALS MAC").font(Fonts.mono(10, .medium)).tracking(2.4).foregroundStyle(Theme.eyebrow)
            }
            .padding(.horizontal, 22).padding(.top, 46).padding(.bottom, 30)

            VStack(spacing: 2) {
                ForEach(Section.allCases) { s in SidebarItem(section: s, selected: section == s) { section = s } }
            }.padding(.horizontal, 12)

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                if let g = model.runningGame {
                    StatusChip(text: "\(g.displayName) running", color: Theme.ok)
                } else {
                    StatusChip(text: model.launchState.label, color: stateColor(model.launchState))
                }
                Text("Command your legacy.\nNative on Mac.")
                    .font(Fonts.body(11)).foregroundStyle(Theme.eyebrow).lineSpacing(2)
                Text("v\(Diagnostics.launcherVersion) · arm64").font(Fonts.mono(10)).foregroundStyle(Theme.edge)
            }.padding(22)
        }
        .frame(width: 236)
        .background(Theme.ink.opacity(0.65))
    }
}

struct SidebarItem: View {
    let section: Section; let selected: Bool; let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.icon).font(.system(size: 13, weight: .medium)).frame(width: 18)
                    .foregroundStyle(selected ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.mute))
                Text(section.rawValue).font(Fonts.body(13.5, selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Theme.text : Theme.mute)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? Theme.surface2 : (hover ? Theme.surface : .clear)))
            .overlay(alignment: .leading) {
                if selected { Capsule().fill(Theme.gradient).frame(width: 3, height: 18).offset(x: -1) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

func stateColor(_ s: LaunchState) -> Color {
    switch s {
    case .running: return Theme.ok
    case .failed: return Theme.bad
    case .idle: return Theme.titanium
    default: return Theme.warn
    }
}

struct ErrorBanner: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        if let e = model.lastError {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.bad)
                Text(e).font(Fonts.body(12.5)).foregroundStyle(Theme.text).lineLimit(3).textSelection(.enabled)
                Spacer()
                Button("Dismiss") { model.lastError = nil }.buttonStyle(GhostButtonStyle())
            }
            .padding(14)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: Theme.r, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.r, style: .continuous).strokeBorder(Theme.bad.opacity(0.5)))
            .padding(18).padding(.leading, 236)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @Binding var section: Section

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "Novexa · Command Center")
                (Text("Command your ").font(Fonts.display(40, .bold))
                 + Text("legacy.").font(Fonts.display(40, .bold)).foregroundStyle(Theme.gradient))
                    .foregroundStyle(Theme.text)
                Text(subtitle).font(Fonts.body(15)).foregroundStyle(Theme.mute).frame(maxWidth: 620, alignment: .leading)
            }

            HStack(alignment: .top, spacing: 20) {
                GameHeroCard(game: .zeroHour) { section = .zeroHour }
                GameHeroCard(game: .generals) { section = .generals }
            }

            HStack(alignment: .top, spacing: 16) {
                InfoTile(label: "Engine", value: engineText, detail: "Native Apple Silicon · no emulation")
                InfoTile(label: "Graphics", value: "Metal", detail: "D3D8 → DXVK → MoltenVK")
                InfoTile(label: "Last played", value: model.settings.lastPlayed?.displayName ?? "—",
                         detail: model.settings.lastPlayedDate?.formatted(date: .abbreviated, time: .shortened) ?? "Not played yet")
            }

            HStack(spacing: 10) {
                Button { model.autoDetect() } label: { Label("Auto-detect", systemImage: "sparkle.magnifyingglass") }
                Button { model.showSteamSheet = true } label: { Label("Download from Steam", systemImage: "arrow.down.circle") }
                Button { model.refresh() } label: { Label("Rescan", systemImage: "arrow.clockwise") }
            }.buttonStyle(GhostButtonStyle())

            RuntimePanel()
            Text(LegalText.disclaimer).font(Fonts.body(11)).foregroundStyle(Theme.eyebrow)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var subtitle: String {
        if let g = model.settings.lastPlayed {
            return "Welcome back, Commander. \(g.displayName) is ready when you are."
        }
        return "Run Generals and Zero Hour natively on Apple Silicon with your own game files."
    }
    var engineText: String {
        if let e = model.engines[.zeroHour] ?? model.engines[.generals] {
            return e.version?.components(separatedBy: " (").first ?? "GeneralsX"
        }
        return "Not installed"
    }
}

struct InfoTile: View {
    let label: String; let value: String; let detail: String
    var body: some View {
        Card(padding: 18) {
            Text(label.uppercased()).font(Fonts.mono(10, .medium)).tracking(1.4).foregroundStyle(Theme.eyebrow)
            Text(value).font(Fonts.display(20, .semibold)).foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.7)
            Text(detail).font(Fonts.body(12)).foregroundStyle(Theme.mute).lineLimit(1)
        }
    }
}

/// Large artwork card for a game, using the cover art from the player's own install.
struct GameHeroCard: View {
    @EnvironmentObject var model: AppModel
    let game: GameKind
    let open: () -> Void
    @State private var hover = false

    var body: some View {
        let report = model.reports[game]
        let engine = model.engines[game]
        let ready = report?.isLaunchable == true && engine?.isUsable == true
        ZStack(alignment: .bottomLeading) {
            GameArtwork(game: game, kind: .cover)
                .scaleEffect(hover ? 1.04 : 1.0)
                .animation(.easeOut(duration: 0.4), value: hover)
            LinearGradient(colors: [.clear, Theme.ink.opacity(0.55), Theme.ink.opacity(0.96)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatusChip(text: ready ? "Ready" : (report?.isLaunchable == true ? "Engine missing" : "Not installed"),
                               color: ready ? Theme.ok : Theme.warn)
                    Spacer()
                    if model.steamDownloadPending.contains(game) {
                        StatusChip(text: "Downloading", color: Theme.magenta)
                    }
                }
                Spacer()
                Text(game == .zeroHour ? "ZERO HOUR · EXPANSION" : "GENERALS · ORIGINAL GAME")
                    .font(Fonts.mono(10, .medium)).tracking(1.6).foregroundStyle(Theme.titanium)
                if GameArt.cover(game, installPath: model.settings[game].installPath) == nil {
                    Text(game == .zeroHour ? "Generals Zero Hour" : "Generals")
                        .font(Fonts.display(26, .bold)).foregroundStyle(.white)
                }
                HStack(spacing: 10) {
                    PlayButton(game: game)
                    Button("Details", action: open).buttonStyle(GhostButtonStyle())
                    if report?.isLaunchable != true {
                        Button("Get from Steam") { model.showSteamSheet = true }.buttonStyle(GhostButtonStyle())
                    }
                }
            }
            .padding(20)
        }
        .frame(height: 340)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous)
            .strokeBorder(hover ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.line), lineWidth: hover ? 1.5 : 1))
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
        .onHover { hover = $0 }
        .dropDestination(for: URL.self) { urls, _ in
            guard let u = urls.first else { return false }
            model.setInstall(u, for: game); return true
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(game.displayName)
    }
}

/// Official art from the user's install, or a branded placeholder when the game isn't set up.
struct GameArtwork: View {
    @EnvironmentObject var model: AppModel
    enum Kind { case cover, banner }
    let game: GameKind; let kind: Kind

    var body: some View {
        let path = model.settings[game].installPath
        let img = kind == .cover ? GameArt.cover(game, installPath: path) : (GameArt.banner(game, installPath: path) ?? GameArt.cover(game, installPath: path))
        GeometryReader { geo in
            if let img {
                Image(nsImage: img).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height).clipped()
            } else {
                ZStack {
                    Theme.surface
                    RadialGradient(colors: [(game == .zeroHour ? Theme.ultra : Theme.ember).opacity(0.45), .clear],
                                   center: .topTrailing, startRadius: 10, endRadius: geo.size.width)
                    NovexaStar().fill(Theme.gradient).frame(width: 90, height: 90).rotationEffect(.degrees(45)).opacity(0.85)
                        .offset(y: -30)
                }
            }
        }
    }
}

struct PlayButton: View {
    @EnvironmentObject var model: AppModel
    let game: GameKind
    var large = false
    var body: some View {
        if model.runningGame == game {
            Button { model.stopGame() } label: { Label("Stop", systemImage: "stop.fill") }.buttonStyle(StopButtonStyle())
        } else {
            Button { model.play(game) } label: { Label("Play", systemImage: "play.fill") }
                .buttonStyle(PrimaryButtonStyle(large: large))
                .disabled(model.runningGame != nil)
                .keyboardShortcut(game == .zeroHour ? "p" : "g", modifiers: .command)
        }
    }
}

struct RuntimePanel: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        Card {
            HStack {
                SectionHeader(title: "Runtime")
                Spacer()
                StatusChip(text: model.launchState.label + (model.runningGame.map { " · \($0.displayName)" } ?? ""),
                           color: stateColor(model.launchState))
            }
            if model.consoleTail.isEmpty {
                Text("Engine output appears here while a game is running. Every launch is logged in Diagnostics.")
                    .font(Fonts.body(12.5)).foregroundStyle(Theme.mute)
            } else {
                ScrollView {
                    Text(model.consoleTail.suffix(80).joined(separator: "\n"))
                        .font(Fonts.mono(11)).foregroundStyle(Theme.mute).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 170)
                .padding(12)
                .background(Theme.ink, in: RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
            }
        }
    }
}

// MARK: - Game detail

struct GameView: View {
    @EnvironmentObject var model: AppModel
    let game: GameKind

    var body: some View {
        let r = model.reports[game]
        VStack(alignment: .leading, spacing: 22) {
            ZStack(alignment: .bottomLeading) {
                GameArtwork(game: game, kind: .cover)
                LinearGradient(colors: [.clear, .clear, Theme.ink.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                HStack(alignment: .bottom, spacing: 18) {
                    if let e = GameArt.emblem(game, installPath: model.settings[game].installPath) {
                        Image(nsImage: e).resizable().frame(width: 72, height: 72).shadow(color: .black.opacity(0.6), radius: 10)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: game == .zeroHour ? "Expansion" : "Original game")
                        if GameArt.cover(game, installPath: model.settings[game].installPath) == nil {
                            Text(game == .zeroHour ? "Generals Zero Hour" : "Generals").font(Fonts.display(34, .bold)).foregroundStyle(.white)
                        } else {
                            let ready = model.reports[game]?.isLaunchable == true && model.engines[game]?.isUsable == true
                            StatusChip(text: ready ? "Ready to deploy" : "Setup required", color: ready ? Theme.ok : Theme.warn)
                        }
                    }
                    Spacer()
                    PlayButton(game: game, large: true)
                }.padding(26)
            }
            .frame(height: 340)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).strokeBorder(Theme.line))

            HStack(alignment: .top, spacing: 18) {
                Card {
                    SectionHeader(title: "Installation")
                    HStack(spacing: 8) {
                        StatusDot(color: r?.isLaunchable == true ? Theme.ok : Theme.warn)
                        Text(r?.summary ?? "—").font(Fonts.body(13, .medium))
                    }
                    KeyValueRow(key: "Folder", value: model.settings[game].installPath ?? "Not selected")
                    if let r, !r.missingRequired.isEmpty { KeyValueRow(key: "Missing (required)", value: r.missingRequired.joined(separator: ", ")) }
                    if let r, !r.invalidArchives.isEmpty { KeyValueRow(key: "Corrupt archives", value: r.invalidArchives.joined(separator: ", ")) }
                    if game == .zeroHour, let dir = model.settings.zeroHour.installPath {
                        KeyValueRow(key: "Generals data", value: LaunchPlanner.generalsDataForZeroHour(zeroHourDir: URL(fileURLWithPath: dir), settings: model.settings)?.path ?? "Not found")
                    }
                    HStack(spacing: 8) {
                        Button("Change…") { model.chooseFolder(for: game) }
                        Button("Steam…") { model.showSteamSheet = true }
                        Button("Revalidate") { model.refresh() }
                        if let p = model.settings[game].installPath {
                            Button { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: p) } label: { Image(systemName: "folder") }
                                .help("Show in Finder")
                        }
                    }.buttonStyle(GhostButtonStyle())
                }
                VStack(spacing: 18) {
                    Card {
                        SectionHeader(title: "Mod")
                        Picker("", selection: $model.settings[game].activeModID) {
                            Text("None — original game").tag(String?.none)
                            ForEach(model.modList.filter { $0.enabled && $0.games.contains(game) }) { Text($0.name).tag(Optional($0.id)) }
                        }.labelsHidden()
                    }
                }.frame(width: 330)
            }

            GraphicsPanel(game: game)
            Card {
                SectionHeader(title: "Advanced")
                TextField("Extra engine arguments, e.g. -noshellmap -quickstart", text: $model.settings[game].extraArguments)
                    .textFieldStyle(.plain).font(Fonts.mono(12))
                    .padding(10).background(Theme.ink, in: RoundedRectangle(cornerRadius: Theme.rSm))
                    .overlay(RoundedRectangle(cornerRadius: Theme.rSm).strokeBorder(Theme.line))
                Text("Black window or lost mouse? Switch to Windowed with a preset resolution. Every launch is logged in Diagnostics.")
                    .font(Fonts.body(12)).foregroundStyle(Theme.mute)
            }
            RuntimePanel()
        }
    }
}

/// Resolutions are physical pixels (the engine renders at exactly this size; on Retina the
/// window is half as large in points, so the image is pin-sharp).
struct ResolutionPicker: View {
    @Binding var width: Int; @Binding var height: Int
    let fullscreen: Bool
    var options: [(Int, Int, String)] {
        let (nw, nh) = AppModel.nativePixels
        if fullscreen {
            return [(nw, nh, "Native Retina · \(nw)×\(nh)"),
                    (nw * 3 / 4, nh * 3 / 4, "75% · \(nw * 3 / 4)×\(nh * 3 / 4)"),
                    (nw / 2, nh / 2, "50% (fastest) · \(nw / 2)×\(nh / 2)")]
        }
        return [(1920, 1080, "1920×1080 px · 960×540 window"),
                (2560, 1440, "2560×1440 px · 1280×720 window"),
                (2880, 1620, "2880×1620 px · 1440×810 window")]
            .filter { $0.0 <= nw }
    }
    var body: some View {
        Picker("Resolution", selection: Binding(get: { "\(width)x\(height)" }, set: { v in
            let p = v.split(separator: "x").compactMap { Int($0) }; if p.count == 2 { width = p[0]; height = p[1] }
        })) {
            ForEach(options, id: \.2) { o in Text(o.2).tag("\(o.0)x\(o.1)") }
            if !options.contains(where: { $0.0 == width && $0.1 == height }) { Text("\(width)×\(height) px").tag("\(width)x\(height)") }
        }.font(Fonts.body(13))
    }
}

struct GraphicsPanel: View {
    @EnvironmentObject var model: AppModel
    let game: GameKind

    var gfx: Binding<GraphicsSettings> {
        Binding(get: { model.settings[game].graphics ?? .make(.high) },
                set: { model.settings[game].graphics = $0 })
    }
    /// Editing any individual option switches the preset to Custom.
    func bind<T>(_ kp: WritableKeyPath<GraphicsSettings, T>) -> Binding<T> {
        Binding(get: { gfx.wrappedValue[keyPath: kp] },
                set: { var g = gfx.wrappedValue; g[keyPath: kp] = $0; g.preset = .custom; gfx.wrappedValue = g })
    }

    var body: some View {
        let g = gfx.wrappedValue
        Card {
            HStack {
                SectionHeader(title: "Graphics")
                Spacer()
                Picker("", selection: Binding(get: { g.preset }, set: { p in
                    if p != .custom { gfx.wrappedValue = .make(p) } else { var c = g; c.preset = .custom; gfx.wrappedValue = c }
                })) {
                    ForEach(GraphicsPreset.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).labelsHidden().frame(width: 330)
            }

            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Mode", selection: Binding(get: { model.settings[game].displayMode }, set: { m in
                        model.settings[game].displayMode = m
                        let (nw, nh) = AppModel.nativePixels
                        if m == .fullscreen { model.settings[game].width = nw; model.settings[game].height = nh }
                        else { model.settings[game].width = 2560; model.settings[game].height = 1440 }
                    })) {
                        Text("Windowed").tag(DisplayMode.windowed); Text("Fullscreen").tag(DisplayMode.fullscreen)
                    }.pickerStyle(.segmented)
                    ResolutionPicker(width: $model.settings[game].width, height: $model.settings[game].height,
                                     fullscreen: model.settings[game].displayMode == .fullscreen)
                    Picker("Frame rate", selection: bind(\.fpsLimit)) {
                        ForEach([30, 60, 75, 90, 120, 144, 240], id: \.self) { Text("\($0) FPS").tag($0) }
                        Text("Uncapped").tag(0)
                    }
                    Picker("Anti-aliasing", selection: bind(\.antiAliasing)) {
                        Text("Off").tag(0); Text("MSAA 2×").tag(2); Text("MSAA 4×").tag(4); Text("MSAA 8×").tag(8)
                    }
                    Picker("Texture filtering", selection: bind(\.anisotropy)) {
                        ForEach([2, 4, 8, 16], id: \.self) { Text("Anisotropic \($0)×").tag($0) }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Draw distance  \(String(format: "%.2f", g.terrainDrawDistance))×").font(Fonts.body(12.5)).foregroundStyle(Theme.mute)
                        Slider(value: bind(\.terrainDrawDistance), in: 1.0...1.5, step: 0.05)
                    }
                }
                .font(Fonts.body(13))
                .frame(maxWidth: 380)

                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 10) {
                    Toggle("Shadows", isOn: bind(\.shadows))
                    Toggle("Advanced shadows", isOn: bind(\.advancedShadows))
                    Toggle("Advanced lighting", isOn: bind(\.advancedLighting))
                    Toggle("Explosion lights", isOn: bind(\.dynamicLights))
                    Toggle("Vehicle headlights", isOn: bind(\.vehicleHeadlights))
                    Toggle("Water reflections", isOn: bind(\.waterReflections))
                    Toggle("Heat haze", isOn: bind(\.heatEffects))
                    Toggle("Extra animations", isOn: bind(\.extraAnimations))
                    Toggle("FXAA", isOn: bind(\.fxaa))
                    Toggle("Bloom", isOn: bind(\.bloom))
                    Toggle("HDR", isOn: bind(\.hdr))
                }
                .toggleStyle(.switch).controlSize(.small).font(Fonts.body(13))
            }
            Toggle("Show FPS overlay (Metal performance HUD)", isOn: Binding(
                get: { model.settings[game].showPerformanceHUD ?? false },
                set: { model.settings[game].showPerformanceHUD = $0 }))
                .toggleStyle(.switch).controlSize(.small).font(Fonts.body(13))
            Text("Applied to the game's Options.ini and SagePatch.ini when you press Play (previous files are backed up). Game logic always runs at 30 ticks per second; a higher frame rate makes camera movement and animation smoother.")
                .font(Fonts.body(11.5)).foregroundStyle(Theme.mute).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Page header

struct PageHeader<Trailing: View>: View {
    let eyebrow: String; let title: String; var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: eyebrow)
                Text(title).font(Fonts.display(32, .bold)).foregroundStyle(Theme.text)
                if let subtitle { Text(subtitle).font(Fonts.body(14)).foregroundStyle(Theme.mute).frame(maxWidth: 640, alignment: .leading) }
            }
            Spacer()
            trailing
        }
    }
}

// MARK: - Mods

struct ModsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(eyebrow: "Novexa · Mods", title: "Mods",
                       subtitle: "Mods are copied into isolated profiles and passed to the engine with -mod. Your game folders are never modified. Compatibility isn't guaranteed until a mod is tested.") {
                Menu {
                    Button("For Zero Hour") { model.importMod(games: [.zeroHour]) }
                    Button("For Generals") { model.importMod(games: [.generals]) }
                    Button("For both") { model.importMod(games: GameKind.allCases) }
                } label: { Label("Import mod", systemImage: "plus") }
                .menuStyle(.borderlessButton).fixedSize()
                .padding(.horizontal, 18).padding(.vertical, 8)
                .background(Theme.gradient, in: Capsule())
            }
            Card {
                SectionHeader(title: "Installed")
                if model.modList.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No mods yet").font(Fonts.display(16, .semibold))
                        Text("Import a .big file, a .zip or a mod folder.").font(Fonts.body(13)).foregroundStyle(Theme.mute)
                    }.padding(.vertical, 8)
                }
                ForEach(model.modList) { m in
                    HStack(spacing: 14) {
                        Toggle("", isOn: Binding(get: { m.enabled }, set: { _ in model.toggleMod(m) })).labelsHidden().toggleStyle(.switch)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(m.name).font(Fonts.body(14, .semibold))
                            Text("\(m.games.map(\.displayName).joined(separator: " · ")) — \(m.files.count) files").font(Fonts.mono(11)).foregroundStyle(Theme.mute)
                        }
                        Spacer()
                        Button("Remove") { model.removeMod(m) }.buttonStyle(GhostButtonStyle()).help("A backup is created before removal")
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
                }
            }
            ForEach(GameKind.allCases) { g in
                let c = model.mods.conflicts(for: g)
                if !c.isEmpty {
                    Card {
                        SectionHeader(title: "\(g.displayName) conflicts")
                        ForEach(c.keys.sorted().prefix(30), id: \.self) { f in KeyValueRow(key: f, value: c[f]!.joined(separator: " vs ")) }
                    }
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(eyebrow: "Novexa · Settings", title: "Settings") { EmptyView() }
            HStack(alignment: .top, spacing: 18) {
                Card {
                    SectionHeader(title: "Installation")
                    KeyValueRow(key: "Generals", value: model.settings.generals.installPath ?? "Not set")
                    KeyValueRow(key: "Zero Hour", value: model.settings.zeroHour.installPath ?? "Not set")
                    HStack(spacing: 8) {
                        Button("Auto-detect") { model.autoDetect() }
                        Button("Download from Steam…") { model.showSteamSheet = true }
                    }.buttonStyle(GhostButtonStyle())
                }
                Card {
                    SectionHeader(title: "Audio")
                    Toggle("Mute all game audio", isOn: $model.settings.muted).toggleStyle(.switch).font(Fonts.body(13))
                    Text("Music, effects and voice levels are set in the game's own Options menu.")
                        .font(Fonts.body(12)).foregroundStyle(Theme.mute)
                }.frame(width: 320)
            }
            OnlinePanel()
            Card {
                SectionHeader(title: "Engine")
                TextField("Custom engine directory (optional)", text: Binding(get: { model.settings.engineDirectory ?? "" },
                          set: { model.settings.engineDirectory = $0.isEmpty ? nil : $0; model.refresh() }))
                    .textFieldStyle(.plain).font(Fonts.mono(12))
                    .padding(10).background(Theme.ink, in: RoundedRectangle(cornerRadius: Theme.rSm))
                    .overlay(RoundedRectangle(cornerRadius: Theme.rSm).strokeBorder(Theme.line))
                KeyValueRow(key: "Compatibility", value: "Native arm64 GeneralsX engine — no Wine, Rosetta or VM")
            }
            Card {
                HStack {
                    SectionHeader(title: "Backups")
                    Spacer()
                    Button("Back up now") { model.backupNow() }.buttonStyle(PrimaryButtonStyle())
                    Button("Open folder") { NSWorkspace.shared.open(model.paths.backupsDir) }.buttonStyle(GhostButtonStyle())
                }
                if model.backups.isEmpty { Text("No backups yet.").font(Fonts.body(13)).foregroundStyle(Theme.mute) }
                ForEach(model.backups.prefix(10)) { b in
                    HStack {
                        Text(b.id).font(Fonts.mono(12))
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: b.size, countStyle: .file)).font(Fonts.mono(11)).foregroundStyle(Theme.mute)
                        Button("Restore") { model.restore(b) }.buttonStyle(GhostButtonStyle())
                    }
                }
            }
            Card {
                SectionHeader(title: "Updates & privacy")
                Text("No telemetry. The launcher only connects to the internet when you start a Steam download.")
                    .font(Fonts.body(13)).foregroundStyle(Theme.mute)
            }
        }
    }
}

// MARK: - Diagnostics

struct DiagnosticsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        let report = Diagnostics.collect(settings: model.settings, paths: model.paths)
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(eyebrow: "Novexa · Diagnostics", title: "Diagnostics") {
                HStack(spacing: 8) {
                    Button("Open logs") { NSWorkspace.shared.open(model.paths.logsDir) }.buttonStyle(GhostButtonStyle())
                    Button("Export logs…") { model.exportLogs() }.buttonStyle(PrimaryButtonStyle())
                }
            }
            Card {
                SectionHeader(title: "System")
                ForEach(Array(report.entries.enumerated()), id: \.offset) { KeyValueRow(key: $0.element.0, value: $0.element.1) }
            }
            ForEach(GameKind.allCases) { g in
                if let r = model.reports[g], !r.missingRequired.isEmpty || !r.missingRecommended.isEmpty {
                    Card {
                        SectionHeader(title: "\(g.displayName) missing files")
                        Text((r.missingRequired + r.missingRecommended).joined(separator: ", ")).font(Fonts.mono(12))
                    }
                }
            }
            RuntimePanel()
        }
    }
}

struct SteamDownloadSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var account = ""
    @State private var zeroHour = true
    @State private var generals = true

    var valid: Bool { SteamDownloader.isValidAccountName(account.trimmingCharacters(in: .whitespaces)) && (zeroHour || generals) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Novexa · Steam")
            Text("Download from Steam").font(Fonts.display(24, .bold)).foregroundStyle(Theme.text)
            Text("Downloads your own copy from your Steam account using Valve's official SteamCMD. You must own the games on Steam (e.g. Command & Conquer: The Ultimate Collection).")
                .font(Fonts.body(12.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Steam account name").font(Fonts.body(12.5, .semibold)).foregroundStyle(Theme.text)
                TextField("e.g. omar123", text: $account).textFieldStyle(.roundedBorder)
                Text("Find it in Steam → Settings → Account → Account name. Not your profile name.")
                    .font(Fonts.body(11.5)).foregroundStyle(Theme.dim)
                if !account.isEmpty && !SteamDownloader.isValidAccountName(account.trimmingCharacters(in: .whitespaces)) {
                    Text("Account names contain only letters, numbers and _").font(Fonts.body(11.5)).foregroundStyle(Theme.bad)
                }
            }
            Toggle("Zero Hour (includes the Generals data it needs) — ~2.8 GB", isOn: $zeroHour)
            Toggle("Generals — ~1.7 GB", isOn: $generals)
            Panel {
                Label("A Terminal window will open. Type your Steam password and Steam Guard code there. NOVEXA never sees them.", systemImage: "lock.shield")
                    .font(Fonts.body(12.5)).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
                Text("Files are saved to ~/Games/ZeroHour and ~/Games/Generals and linked automatically when the download completes.")
                    .font(Fonts.body(11.5)).foregroundStyle(Theme.dim)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(GhostButtonStyle())
                Button("Open Terminal & Download") {
                    var games: [GameKind] = []
                    if zeroHour { games.append(.zeroHour) }
                    if generals { games.append(.generals) }
                    model.startSteamDownload(account: account, games: games)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!valid)
            }
        }
        .padding(28).frame(width: 540).background(Backdrop()).preferredColorScheme(.dark)
    }
}


struct OnlinePanel: View {
    var body: some View {
        Card {
            HStack {
                SectionHeader(title: "Online")
                Spacer()
                StatusChip(text: "NOVEXA Online", color: Theme.ok)
            }
            Text("Zero Hour multiplayer runs on NOVEXA's servers (\(OnlineSettings.novexaHost)). In the game choose Online — your browser opens to sign in with Discord.")
                .font(Fonts.body(12.5)).foregroundStyle(Theme.mute).fixedSize(horizontal: false, vertical: true)
        }
    }
}


enum LegalText {
    static let disclaimer = "NOVEXA is not affiliated with, endorsed by, or sponsored by Electronic Arts Inc. Command & Conquer, Generals and Zero Hour are trademarks of Electronic Arts Inc., used only to describe compatibility. No game content is included — you need your own copy."
    static let sourceURL = URL(string: "https://github.com/OmaryaToo/novexa-generals-mac-source")!
    static var legalFolder: URL? {
        let u = Bundle.main.resourceURL?.appendingPathComponent("Legal")
        return u.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(eyebrow: "Novexa · About", title: "About & Licenses") { EmptyView() }
            Card {
                SectionHeader(title: "NOVEXA Generals Mac")
                Text("© 2026 NOVEXA · novexa-jo.com · Launcher version \(Diagnostics.launcherVersion)").font(Fonts.body(13))
                Text(LegalText.disclaimer).font(Fonts.body(12.5)).foregroundStyle(Theme.mute).fixedSize(horizontal: false, vertical: true)
            }
            Card {
                SectionHeader(title: "Game engine")
                Text("NOVEXA ZH and NOVEXA Classic are modified versions of GeneralsX, which is based on the Command & Conquer Generals / Zero Hour source code released by Electronic Arts under the GNU GPL v3 with additional terms. Original code © Electronic Arts and the GeneralsX and TheSuperHackers contributors. NOVEXA's changes (2026): online-server selection, neutral branding and macOS packaging.")
                    .font(Fonts.body(12.5)).foregroundStyle(Theme.mute).fixedSize(horizontal: false, vertical: true)
                KeyValueRow(key: "License", value: "GPL-3.0 with EA additional terms")
                KeyValueRow(key: "Online services", value: "GeneralsOnline (AGPL-3.0), hosted by NOVEXA")
            }
            Card {
                SectionHeader(title: "Source code & licenses")
                Text("The complete source code of this app, including NOVEXA's modifications, and the licenses of all 29 third-party components shipped with it.")
                    .font(Fonts.body(12.5)).foregroundStyle(Theme.mute).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("Open licenses folder") { if let u = LegalText.legalFolder { NSWorkspace.shared.open(u) } }
                        .buttonStyle(PrimaryButtonStyle()).disabled(LegalText.legalFolder == nil)
                    Button("Source code") { NSWorkspace.shared.open(LegalText.sourceURL) }.buttonStyle(GhostButtonStyle())
                }
            }
            Text("This software is provided \"as is\", without warranty of any kind.").font(Fonts.body(11)).foregroundStyle(Theme.eyebrow)
        }
    }
}
