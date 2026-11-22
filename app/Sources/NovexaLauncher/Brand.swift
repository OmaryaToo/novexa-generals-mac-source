import SwiftUI

/// The Novexa wordmark ("nove✦a"), redrawn from novexa-jo.com/assets/brand/novexa-wordmark.svg
/// (viewBox -14 16 546 98) as native paths, so it can be stroked in a light colour on dark UI.
struct NovexaWordmark: View {
    var stroke: Color = Theme.text
    var body: some View {
        Canvas { ctx, size in
            let vb = CGRect(x: -14, y: 16, width: 546, height: 98)
            let s = min(size.width / vb.width, size.height / vb.height)
            ctx.translateBy(x: (size.width - vb.width * s) / 2 - vb.minX * s, y: (size.height - vb.height * s) / 2 - vb.minY * s)
            ctx.scaleBy(x: s, y: s)
            var p = Path()
            // n
            p.move(to: CGPoint(x: 0, y: 30)); p.addLine(to: CGPoint(x: 0, y: 100))
            p.move(to: CGPoint(x: 0, y: 60))
            p.addArc(center: CGPoint(x: 28, y: 60), radius: 28, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: CGPoint(x: 56, y: 100))
            // o
            p.addEllipse(in: CGRect(x: 82, y: 30, width: 70, height: 70))
            // v
            p.move(to: CGPoint(x: 174, y: 30)); p.addLine(to: CGPoint(x: 205, y: 100)); p.addLine(to: CGPoint(x: 236, y: 30))
            // e
            p.move(to: CGPoint(x: 261, y: 65)); p.addLine(to: CGPoint(x: 331, y: 65))
            p.addArc(center: CGPoint(x: 296, y: 65), radius: 35, startAngle: .degrees(0), endAngle: .degrees(45), clockwise: true)
            // a
            p.addEllipse(in: CGRect(x: 448, y: 30, width: 70, height: 70))
            p.move(to: CGPoint(x: 518, y: 30)); p.addLine(to: CGPoint(x: 518, y: 100))
            ctx.stroke(p, with: .color(stroke), style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))
            // ✦ (the "x")
            var star = NovexaStar.path(in: CGRect(x: -100, y: -100, width: 200, height: 200))
            star = star.applying(CGAffineTransform(rotationAngle: .pi / 4).scaledBy(x: 0.46, y: 0.46))
                       .applying(CGAffineTransform(translationX: 389, y: 65))
            ctx.fill(star, with: .linearGradient(Gradient(stops: [.init(color: Theme.ultra, location: 0), .init(color: Theme.magenta, location: 0.55), .init(color: Theme.ember, location: 1)]),
                                                 startPoint: CGPoint(x: 343, y: 111), endPoint: CGPoint(x: 435, y: 19)))
        }
        .aspectRatio(546 / 98, contentMode: .fit)
        .accessibilityLabel("Novexa")
    }
}

/// The four-point brand star.
struct NovexaStar: Shape {
    static func path(in r: CGRect) -> Path {
        // M0 -100 C7 -26 26 -7 100 0 C26 7 7 26 0 100 C-7 26 -26 7 -100 0 C-26 -7 -7 -26 0 -100Z  (in a 200x200 box centred on 0)
        let sx = r.width / 200, sy = r.height / 200
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.midX + x * sx, y: r.midY + y * sy) }
        var p = Path()
        p.move(to: pt(0, -100))
        p.addCurve(to: pt(100, 0), control1: pt(7, -26), control2: pt(26, -7))
        p.addCurve(to: pt(0, 100), control1: pt(26, 7), control2: pt(7, 26))
        p.addCurve(to: pt(-100, 0), control1: pt(-7, 26), control2: pt(-26, 7))
        p.addCurve(to: pt(0, -100), control1: pt(-26, -7), control2: pt(-7, -26))
        p.closeSubpath()
        return p
    }
    func path(in rect: CGRect) -> Path { Self.path(in: rect) }
}
