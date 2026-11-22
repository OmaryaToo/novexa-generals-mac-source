// Renders the DMG window background (Novexa palette): "drag the app to Applications".
import AppKit
let out = CommandLine.arguments[1]
let w: CGFloat = 640, h: CGFloat = 400
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w*2), pixelsHigh: Int(h*2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: w, height: h)
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
func c(_ x: UInt32, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: CGFloat((x>>16)&255)/255, green: CGFloat((x>>8)&255)/255, blue: CGFloat(x&255)/255, alpha: a) }
c(0x0B0A14).setFill(); NSRect(x: 0, y: 0, width: w, height: h).fill()
NSGradient(colors: [c(0x7C3AED, 0.35), c(0x7C3AED, 0)])!.draw(fromCenter: NSPoint(x: w, y: h), radius: 0, toCenter: NSPoint(x: w, y: h), radius: 420, options: [])
NSGradient(colors: [c(0xFB923C, 0.18), c(0xFB923C, 0)])!.draw(fromCenter: NSPoint(x: 0, y: 0), radius: 0, toCenter: NSPoint(x: 0, y: 0), radius: 360, options: [])
func text(_ s: String, _ size: CGFloat, _ weight: NSFont.Weight, _ col: NSColor, y: CGFloat, kern: CGFloat = 0) {
    let a = NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: col, .kern: kern])
    a.draw(at: NSPoint(x: (w - a.size().width)/2, y: y))
}
text("NOVEXA GENERALS MAC", 13, .semibold, c(0x8A85A3), y: h - 52, kern: 3)
text("Drag to Applications to install", 20, .bold, c(0xECEAF5), y: h - 88)
text("اسحب التطبيق إلى مجلد Applications للتثبيت", 15, .regular, c(0xABA7C0), y: h - 114)
// arrow between icon slots (icons at x=170 and x=470, y≈200 from top)
let arrow = NSBezierPath(); arrow.lineWidth = 4; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 255, y: 205)); arrow.line(to: NSPoint(x: 385, y: 205))
arrow.move(to: NSPoint(x: 365, y: 219)); arrow.line(to: NSPoint(x: 385, y: 205)); arrow.line(to: NSPoint(x: 365, y: 191))
c(0xEC4899).setStroke(); arrow.stroke()
text("First launch blocked? System Settings → Privacy & Security → Open Anyway", 11.5, .regular, c(0x8A85A3), y: 44)
text("إن مُنع التشغيل: إعدادات النظام ← الخصوصية والأمان ← Open Anyway", 11.5, .regular, c(0x8A85A3), y: 24)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
