import SwiftUI
import AppKit

@main
struct NovexaApp: App {
    @StateObject private var model = AppModel()
    init() {
        Fonts.register()
        DevSnapshot.scheduleIfRequested()
    }
    var body: some Scene {
        WindowGroup("NOVEXA Generals Mac") {
            RootView().environmentObject(model).frame(minWidth: 1100, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}


/// Developer aid: `NOVEXA_SNAPSHOT=/path.png` renders the main window into a PNG and quits.
/// Uses the window's own view hierarchy (no Screen Recording permission needed).
enum DevSnapshot {
    static func scheduleIfRequested() {
        guard let out = ProcessInfo.processInfo.environment["NOVEXA_SNAPSHOT"] else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let size = ProcessInfo.processInfo.environment["NOVEXA_SNAPSHOT_SIZE"]?.split(separator: "x").compactMap({ Double($0) }),
               size.count == 2, let w = NSApp.windows.first(where: { $0.isVisible }) {
                w.setContentSize(NSSize(width: size[0], height: size[1]))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            guard let w = NSApp.windows.first(where: { $0.isVisible }), let v = w.contentView?.superview ?? w.contentView else { NSApp.terminate(nil); return }
            if let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) {
                v.cacheDisplay(in: v.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
            }
            NSApp.terminate(nil)
        }
    }
}
