import SwiftUI

/// Ember, coiled round a record: the h3arth mark, drawn from the pixel art in EmberArt.
struct EmberMark: View {
    var size: CGFloat = 104
    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width / CGFloat(EmberArt.size)
            for (y, row) in EmberArt.rows.enumerated() {
                for (x, ch) in row.enumerated() {
                    guard let c = EmberArt.palette[ch] else { continue }
                    ctx.fill(Path(CGRect(x: CGFloat(x) * s, y: CGFloat(y) * s, width: s + 0.3, height: s + 0.3)),
                             with: .color(Color(red: Double(c.0) / 255, green: Double(c.1) / 255, blue: Double(c.2) / 255)))
                }
            }
        }
        .frame(width: size, height: size)
        .drawingGroup()
        .shadow(color: Color(Pal.emberOrange).opacity(0.45), radius: size / 10)
    }
}

/// H3ARTH in the same block lettering as EMB3R's logo, with the 3 burning.
struct Wordmark: View {
    @Environment(\.pal) private var pal
    var size: CGFloat = 15
    var boot = false          // boot screen: unlit grey letters
    var lit = true            // whether the 3 has caught yet

    static let glyphs: [Character: [String]] = [
        "H": ["██╗  ██╗", "██║  ██║", "███████║", "██╔══██║", "██║  ██║", "╚═╝  ╚═╝"],
        "3": ["██████╗ ", "╚════██╗", " █████╔╝", " ╚═══██╗", "██████╔╝", "╚═════╝ "],
        "A": [" █████╗ ", "██╔══██╗", "███████║", "██╔══██║", "██║  ██║", "╚═╝  ╚═╝"],
        "R": ["██████╗ ", "██╔══██╗", "██████╔╝", "██╔══██╗", "██║  ██║", "╚═╝  ╚═╝"],
        "T": ["████████╗", "╚══██╔══╝", "   ██║   ", "   ██║   ", "   ██║   ", "   ╚═╝   "],
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array("H3ARTH".enumerated()), id: \.offset) { _, ch in
                let hot = ch == "3" && lit
                VStack(spacing: 0) {
                    ForEach(Wordmark.glyphs[ch] ?? [], id: \.self) { row in
                        Text(row).font(.custom("Menlo-Regular", size: size)).fixedSize()
                            .frame(height: size, alignment: .center)   // line height 1, so the blocks join up
                    }
                }
                .foregroundColor(hot ? Color(red: 1, green: 0.81, blue: 0.54) : boot ? Color(white: 0.23) : pal.ph)
                .shadow(color: hot ? Color(red: 1, green: 0.42, blue: 0) : boot ? .clear : pal.ph.opacity(0.7), radius: hot ? 6 : 2)
                .shadow(color: hot ? Color(red: 1, green: 0.24, blue: 0).opacity(0.8) : .clear, radius: 14)
            }
        }
        .fixedSize()
    }
}

/// A cover drawn in phosphor dots (ordered dither), so it belongs to the terminal.
struct DitherArt: View {
    @Environment(\.pal) private var pal
    let dots: [ArtDot]
    let n: Int
    var size: CGFloat
    private static let bayer: [Double] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
    var body: some View {
        Canvas { ctx, sz in
            guard dots.count == n * n else { return }
            let s = sz.width / CGFloat(n)
            for y in 0..<n {
                for x in 0..<n where Double(dots[y * n + x].lum) * 16 > DitherArt.bayer[(y % 4) * 4 + x % 4] + 0.5 {
                    ctx.fill(Path(CGRect(x: CGFloat(x) * s, y: CGFloat(y) * s, width: s * 0.82, height: s * 0.82)), with: .color(pal.ph))
                }
            }
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }
}

/// The ASCII face, emb3r style: changes with what's playing.
func emberFace(playing: Bool) -> String { playing ? "( ♪‿♪ )" : "( -_- ) zz" }
