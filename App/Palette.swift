import SwiftUI
import UIKit

struct ArtDot { let color: Color; let lum: CGFloat }
struct ArtAnalysis { var colors: [Color]; var accent: Color; var dots: [ArtDot] }

/// Pulls the main colours and an n x n dot grid out of an album cover.
enum Palette {
    static func analyze(_ img: UIImage, n: Int) -> ArtAnalysis {
        let none = ArtAnalysis(colors: [], accent: Theme.red, dots: [])
        guard let cg = img.cgImage else { return none }
        var px = [UInt8](repeating: 0, count: n * n * 4)
        px.withUnsafeMutableBytes { buf in
            if let ctx = CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                ctx.interpolationQuality = .medium
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
            }
        }
        var dots: [ArtDot] = []
        var buckets: [Int: (w: Double, r: Double, g: Double, b: Double)] = [:]
        for i in stride(from: 0, to: px.count, by: 4) {
            let r = Double(px[i]) / 255, g = Double(px[i + 1]) / 255, b = Double(px[i + 2]) / 255
            let mx = max(r, g, b), mn = min(r, g, b)
            let sat = mx == 0 ? 0 : (mx - mn) / mx
            dots.append(ArtDot(color: Color(red: r, green: g, blue: b), lum: CGFloat(0.2126 * r + 0.7152 * g + 0.0722 * b)))
            let w = 0.1 + sat * (0.3 + mx)          // favour vivid, bright pixels
            let key = (Int(r * 3.99) << 6) | (Int(g * 3.99) << 3) | Int(b * 3.99)
            var e = buckets[key] ?? (w: 0, r: 0, g: 0, b: 0)
            e.w += w; e.r += r * w; e.g += g * w; e.b += b * w
            buckets[key] = e
        }
        var picked: [(Double, Double, Double)] = []
        for e in buckets.values.sorted(by: { $0.w > $1.w }) {
            let c = (e.r / e.w, e.g / e.w, e.b / e.w)
            if picked.allSatisfy({ abs($0.0 - c.0) + abs($0.1 - c.1) + abs($0.2 - c.2) > 0.6 }) { picked.append(c) }
            if picked.count == 3 { break }
        }
        guard let first = picked.first else { return ArtAnalysis(colors: [], accent: Theme.red, dots: dots) }
        let m = max(first.0, first.1, first.2, 0.01)
        let k = m < 0.75 ? 0.75 / m : 1       // lift dark colours so dots stay readable
        let accent = Color(red: min(first.0 * k, 1), green: min(first.1 * k, 1), blue: min(first.2 * k, 1))
        return ArtAnalysis(colors: picked.map { Color(red: $0.0, green: $0.1, blue: $0.2) }, accent: accent, dots: dots)
    }
}

@MainActor
final class ArtModel: ObservableObject {
    let n = 40
    @Published var image: UIImage?
    @Published var colors: [Color] = []
    @Published var accent: Color = Theme.red
    @Published var dots: [ArtDot] = []
    private var url: String?

    func load(_ s: String?) async {
        guard let s, s != url, let u = URL(string: s) else { return }
        url = s
        guard let (data, _) = try? await URLSession.shared.data(from: u), let img = UIImage(data: data) else { return }
        let n = self.n
        let a = await Task.detached { Palette.analyze(img, n: n) }.value
        guard url == s else { return }
        image = img; colors = a.colors; accent = a.accent; dots = a.dots
    }
}

/// Album art turned into a halftone dot field.
struct Halftone: View {
    let dots: [ArtDot]
    let n: Int
    var body: some View {
        Canvas { ctx, size in
            guard dots.count == n * n else { return }
            let cell = max(size.width, size.height) / CGFloat(n)
            let ox = (size.width - cell * CGFloat(n)) / 2, oy = (size.height - cell * CGFloat(n)) / 2
            for y in 0..<n {
                for x in 0..<n {
                    let d = dots[y * n + x]
                    let r = cell * (0.1 + 0.4 * d.lum)
                    let cx = ox + (CGFloat(x) + 0.5) * cell, cy = oy + (CGFloat(y) + 0.5) * cell
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)), with: .color(d.color))
                }
            }
        }
        .drawingGroup()   // render once into a texture instead of redrawing 1600 dots
    }
}
