import SwiftUI

extension String {
    /// The dot font only has plain upper-case: strip accents, show "?" for anything else.
    var dotSafe: String {
        String(folding(options: [.diacriticInsensitive], locale: nil).uppercased()
            .map { DotFont.glyphs[$0] != nil ? $0 : "?" })
    }
}

/// Word-wrap into rows of at most `cols` dot-characters.
func wrapDots(_ s: String, cols: Int) -> [String] {
    var rows: [String] = [], cur = ""
    for w in s.dotSafe.split(separator: " ") {
        if cur.isEmpty { cur = String(w) }
        else if cur.count + 1 + w.count <= cols { cur += " " + w }
        else { rows.append(String(cur.prefix(cols))); cur = String(w) }
    }
    if !cur.isEmpty { rows.append(String(cur.prefix(cols))) }
    return rows
}

/// One line of 5x7 dot-matrix text. `dot` is the pitch between dots.
struct DotText: View {
    let text: String
    var dot: CGFloat = 4
    var color: Color = .white
    var off: Color? = nil          // draw unlit dots too (LED panel look)

    var body: some View {
        let chars = Array(text.dotSafe)
        Canvas { ctx, _ in
            for (i, ch) in chars.enumerated() {
                for (y, bits) in DotFont.rows(ch).enumerated() {
                    for x in 0..<5 {
                        let on = bits & (1 << UInt8(4 - x)) != 0
                        if !on && off == nil { continue }
                        let r = dot * (on ? 0.42 : 0.17)
                        let cx = (CGFloat(i * 6 + x) + 0.5) * dot
                        let cy = (CGFloat(y) + 0.5) * dot
                        ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)),
                                 with: .color(on ? color : (off ?? .clear)))
                    }
                }
            }
        }
        .frame(width: CGFloat(max(chars.count * 6 - 1, 1)) * dot, height: 7 * dot)
    }
}

/// Dot text that scrolls like a ticker when it is longer than `cols`.
struct DotMarquee: View {
    let text: String
    var cols: Int = 20
    var dot: CGFloat = 5
    var color: Color = .white

    var body: some View {
        let s = text.dotSafe
        if s.count <= cols {
            DotText(text: s, dot: dot, color: color)
        } else {
            TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                let padded = Array(s + "   ")
                let step = Int(ctx.date.timeIntervalSinceReferenceDate * 4) % padded.count
                let window = (0..<cols).map { padded[($0 + step) % padded.count] }
                DotText(text: String(window), dot: dot, color: color)
            }
        }
    }
}

/// Row of dots that fills left to right (progress).
struct DotBar: View {
    let frac: Double
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            let n = 64
            let step = size.width / CGFloat(n)
            let r = min(step * 0.32, size.height / 2)
            for i in 0..<n {
                let on = Double(i) / Double(n) < frac
                ctx.fill(Path(ellipseIn: CGRect(x: CGFloat(i) * step + step / 2 - r, y: size.height / 2 - r, width: 2 * r, height: 2 * r)),
                         with: .color(on ? color : Color.white.opacity(0.18)))
            }
        }
    }
}

/// Decorative LED level meter (animated while playing; it does not read the real audio).
struct VU: View {
    let color: Color
    let active: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.09)) { ctx in
            Canvas { g, size in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let cols = 14, rows = 6
                let cw = size.width / CGFloat(cols), rh = size.height / CGFloat(rows)
                for c in 0..<cols {
                    let a = 0.45 + 0.45 * sin(t * (2.1 + Double(c) * 0.37) + Double(c))
                    let b = 0.7 + 0.3 * sin(t * 0.9 + Double(c) * 2)
                    let level = active ? a * b : 0.08
                    let lit = Int((level * Double(rows)).rounded())
                    for r in 0..<rows {
                        let rect = CGRect(x: CGFloat(c) * cw + 2, y: size.height - CGFloat(r + 1) * rh + 1, width: cw - 4, height: rh - 3)
                        let col: Color = r < lit ? (r >= rows - 1 ? Theme.red : color) : Color.white.opacity(0.08)
                        g.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(col))
                    }
                }
            }
        }
    }
}

/// Thin CRT scanlines for the retro feel.
struct Scanlines: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(Color.black.opacity(0.18)))
                y += 3
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
