// Renders the NOVEXA app icon: the Novexa four-point star (brand gradient) on an ink tile.
// Geometry from novexa-jo.com/assets/brand/novexa-wordmark.svg. No EA artwork.
import AppKit
let out = CommandLine.arguments[1]
/// Optional caption under the star (e.g. "ZERO HOUR") for per-game engine icons.
let caption = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
func c(_ h: UInt32, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: CGFloat((h>>16)&255)/255, green: CGFloat((h>>8)&255)/255, blue: CGFloat(h&255)/255, alpha: a) }
func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px), inset = s * 0.09
    let tile = NSRect(x: inset, y: inset, width: s - 2*inset, height: s - 2*inset)
    let shape = NSBezierPath(roundedRect: tile, xRadius: s * 0.2, yRadius: s * 0.2)
    c(0x0B0A14).setFill(); shape.fill()
    NSGraphicsContext.current!.saveGraphicsState(); shape.addClip()
    NSGradient(colors: [c(0x7C3AED, 0.45), c(0x7C3AED, 0)])!.draw(fromCenter: NSPoint(x: tile.maxX, y: tile.maxY), radius: 0, toCenter: NSPoint(x: tile.maxX, y: tile.maxY), radius: s*0.75, options: [])
    NSGradient(colors: [c(0xFB923C, 0.22), c(0xFB923C, 0)])!.draw(fromCenter: NSPoint(x: tile.minX, y: tile.minY), radius: 0, toCenter: NSPoint(x: tile.minX, y: tile.minY), radius: s*0.6, options: [])
    NSGraphicsContext.current!.restoreGraphicsState()
    c(0xFFFFFF, 0.08).setStroke(); shape.lineWidth = max(1, s*0.004); shape.stroke()
    // star, rotated 45° like the wordmark "x"
    let star = NSBezierPath(); let k = s * 0.0032
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x*k, y: y*k) }
    star.move(to: p(0,-100))
    star.curve(to: p(100,0), controlPoint1: p(7,-26), controlPoint2: p(26,-7))
    star.curve(to: p(0,100), controlPoint1: p(26,7), controlPoint2: p(7,26))
    star.curve(to: p(-100,0), controlPoint1: p(-7,26), controlPoint2: p(-26,7))
    star.curve(to: p(0,-100), controlPoint1: p(-26,-7), controlPoint2: p(-7,-26))
    star.close()
    let cy = caption == nil ? s/2 : s*0.56
    if caption != nil { var sc = AffineTransform(); sc.scale(0.78); star.transform(using: sc) }
    var t = AffineTransform(); t.translate(x: s/2, y: cy); t.rotate(byDegrees: 45); star.transform(using: t)
    NSGraphicsContext.current!.saveGraphicsState(); star.addClip()
    NSGradient(colors: [c(0x7C3AED), c(0xEC4899), c(0xFB923C)], atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
        .draw(in: star.bounds, angle: 45)
    NSGraphicsContext.current!.restoreGraphicsState()
    if let caption, px >= 32 {
        let f = NSFont.systemFont(ofSize: s * 0.085, weight: .heavy)
        let str = NSAttributedString(string: caption, attributes: [.font: f, .foregroundColor: c(0xECEAF5), .kern: s * 0.008])
        let sz = str.size(); str.draw(at: NSPoint(x: (s - sz.width) / 2, y: s * 0.17))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for (name, px) in [("16x16",16),("16x16@2x",32),("32x32",32),("32x32@2x",64),("128x128",128),("128x128@2x",256),("256x256",256),("256x256@2x",512),("512x512",512),("512x512@2x",1024)] {
    try! render(px).write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
