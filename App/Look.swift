import SwiftUI
import UIKit

/// emb3r's colour system: one accent, every other shade mixed from it (its CSS does the same with color-mix).
struct Pal {
    let accent: UIColor
    let ph, hi, bg, quiet, dim, line, lineStrong, hover: Color
    let fill: [Color]          // solid buttons and the playing row; two album colours when an album sets the mood

    init(_ c: UIColor, bg b: UIColor = UIColor(red: 0.043, green: 0.059, blue: 0.043, alpha: 1), fill: [UIColor]? = nil) {
        accent = c
        ph = Color(c); hi = Color(c.mix(.white, 0.55)); bg = Color(b)
        quiet = Color(c.mix(UIColor(red: 0.655, green: 0.682, blue: 0.663, alpha: 1), 0.30))
        dim = Color(c.mix(b, 0.58)); line = Color(c.mix(b, 0.72)); lineStrong = Color(c.mix(b, 0.45)); hover = Color(c.mix(b, 0.86))
        self.fill = (fill ?? [c, c]).map { Color($0) }
    }

    /// Text over an album's colour field: a light tint of its brightest colour, the fill runs through the cover's colours.
    static func album(_ colors: [UIColor]) -> Pal? {
        guard let a = colors.first else { return nil }
        let warm = colors.count > 1 ? colors[1] : a
        return Pal(a.mix(.white, 0.5), bg: a.mix(.black, 0.9), fill: [a.mix(.white, 0.25), warm.mix(.white, 0.1)])
    }

    static let phosphor = "#7CFF9E"   // emb3r's green
    static let presets = ["#7CFF9E", "#FFB020", "#6FE0FF", "#FF6AD5", "#C46BFF", "#FF5A5A", "#E8E8E8"]
    static let emberOrange = UIColor(red: 1, green: 0.416, blue: 0, alpha: 1)
}

extension UIColor {
    /// This colour moved toward `o` by `t` (0 keeps it, 1 is `o`).
    func mix(_ o: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        o.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: 1)
    }

    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        self.init(red: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
    }

    var hex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let c = { (v: CGFloat) in v.isFinite ? Int((max(0, min(1, v)) * 255).rounded()) : 0 }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }

    /// The colour picker's two bars: hue, and a light bar that runs dark -> pure -> pale.
    static func picked(hue: Double, light: Double) -> UIColor {
        light < 0.5
            ? UIColor(hue: hue, saturation: 0.75, brightness: 0.45 + light * 1.1, alpha: 1)
            : UIColor(hue: hue, saturation: 0.75 - (light - 0.5) * 1.3, brightness: 1, alpha: 1)
    }

    var pickerPosition: (hue: Double, light: Double) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let light = b < 0.99 ? (Double(b) - 0.45) / 1.1 : 0.5 + (0.75 - Double(s)) / 1.3
        return (Double(h), max(0, min(1, light)))
    }
}

private struct PalKey: EnvironmentKey { static let defaultValue = Pal(UIColor(hex: Pal.phosphor)!) }
extension EnvironmentValues {
    var pal: Pal { get { self[PalKey.self] } set { self[PalKey.self] = newValue } }
}

extension Font {
    /// VT323, emb3r's terminal face (bundled at build time; falls back to the system font if missing).
    static func term(_ size: CGFloat) -> Font { .custom("VT323-Regular", size: size) }
    static func mono(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font { .system(size: size, weight: w, design: .monospaced) }
}

/// The phosphor bloom round text, like emb3r's text-shadow. Off in Settings for speed.
struct Glow: ViewModifier {
    @Environment(\.pal) private var pal
    @AppStorage("opt.glow") private var on = true
    var strong = false
    @ViewBuilder func body(content: Content) -> some View {
        if on { content.shadow(color: pal.ph.opacity(strong ? 0.85 : 0.6), radius: strong ? 6 : 2.5) } else { content }
    }
}
extension View {
    func glow(_ strong: Bool = false) -> some View { modifier(Glow(strong: strong)) }
    /// emb3r's 1px outline box.
    func box(_ c: Color, _ w: CGFloat = 1) -> some View { overlay(Rectangle().stroke(c, lineWidth: w)) }
}

/// `[ label ]` button, outlined, or filled when `solid`.
struct TermBtn: View {
    @Environment(\.pal) private var pal
    let label: String
    var solid = false
    var size: CGFloat = 21
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("[ \(label) ]").font(.term(size)).lineLimit(1)
                .foregroundColor(solid ? pal.bg : pal.ph)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Group { if solid { LinearGradient(colors: pal.fill, startPoint: .leading, endPoint: .trailing) } else { pal.bg.opacity(0.55) } })
                .box(pal.ph)
                .glow()
        }
    }
}

/// `[x] title  // what it does` - the checkbox row emb3r's settings use.
struct TermToggle: View {
    @Environment(\.pal) private var pal
    let title: String
    let sub: String
    @Binding var on: Bool
    var body: some View {
        Button { on.toggle() } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(on ? "[x]" : "[ ]").font(.mono(15)).foregroundColor(pal.ph)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.term(23)).foregroundColor(pal.ph)
                    Text("// " + sub).font(.term(18)).foregroundColor(pal.quiet)
                }
                Spacer(minLength: 0)
            }
            .glow()
        }
    }
}

/// `2:14 [#########-------] 3:48`
func asciiBar(_ frac: Double, _ width: Int) -> String {
    let n = max(0, min(width, Int((frac * Double(width)).rounded())))
    return "[" + String(repeating: "#", count: n) + String(repeating: "-", count: width - n) + "]"
}

func clock(_ ms: Int) -> String { String(format: "%d:%02d", ms / 60000, (ms / 1000) % 60) }

/// Thin CRT lines, drawn once into a texture.
struct Scanlines: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(Color.black.opacity(0.16)))
                y += 3
            }
        }
        .allowsHitTesting(false)
    }
}

/// Gentle press feedback on every button.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
