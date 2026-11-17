import SwiftUI
import UIKit
import CoreImage

struct ArtDot { let color: Color; let lum: CGFloat }
struct ArtAnalysis { var colors: [UIColor]; var dots: [ArtDot]; var field: UIImage? }

/// Pulls the main colours, an n x n dot grid, and the album colour field out of a cover.
enum Palette {
    static func analyze(_ img: UIImage, n: Int) -> ArtAnalysis {
        guard let cg = img.cgImage else { return ArtAnalysis(colors: [], dots: [], field: nil) }
        var px = [UInt8](repeating: 0, count: n * n * 4)
        px.withUnsafeMutableBytes { buf in
            if let ctx = CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
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
        let colors = picked.map { c -> UIColor in
            let m = max(c.0, c.1, c.2, 0.01), k = m < 0.75 ? 0.75 / m : 1   // lift dark colours so text stays readable
            return UIColor(red: min(c.0 * k, 1), green: min(c.1 * k, 1), blue: min(c.2 * k, 1), alpha: 1)
        }
        return ArtAnalysis(colors: colors, dots: dots, field: field(cg))
    }

    /// The album colour field: the cover shrunk to 5x5 and spread back out, so the gradient is the
    /// cover's own colours in the cover's own places. Blurred and saturated once here, not every frame.
    static func field(_ cg: CGImage) -> UIImage? {
        let tiny = CIImage(cgImage: cg).transformed(by: CGAffineTransform(scaleX: 5 / CGFloat(cg.width), y: 5 / CGFloat(cg.height)))
        let up = tiny.samplingLinear().transformed(by: CGAffineTransform(scaleX: 48, y: 48))   // 240 x 240
        let blurred = up.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 22])
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.7, kCIInputBrightnessKey: -0.04, kCIInputContrastKey: 1.1])
            .cropped(to: CGRect(x: 0, y: 0, width: 240, height: 240))
        guard let out = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(blurred, from: blurred.extent) else { return nil }
        return UIImage(cgImage: out)
    }

    /// Film grain over the colour field so it never bands; generated once.
    static let grain: UIImage = {
        let n = 128
        var px = [UInt8](repeating: 0, count: n * n * 4)
        var seed: UInt32 = 7
        for i in stride(from: 0, to: px.count, by: 4) {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let v = UInt8(truncatingIfNeeded: seed >> 24)
            px[i] = v; px[i + 1] = v; px[i + 2] = v; px[i + 3] = 255
        }
        let cg = px.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        return cg.map { UIImage(cgImage: $0) } ?? UIImage()
    }()
}

@MainActor
final class ArtModel: ObservableObject {
    let n = 40
    @Published var image: UIImage?
    @Published var colors: [UIColor] = []
    @Published var dots: [ArtDot] = []
    @Published var field: UIImage?
    private var url: String?

    func load(_ s: String?) async {
        guard let s, s != url, let u = URL(string: s) else { return }
        url = s
        let cached = ImageCache.shared.object(forKey: s as NSString)
        var img = cached
        if img == nil, let (data, _) = try? await URLSession.shared.data(from: u) { img = UIImage(data: data) }
        guard let img else { return }
        if cached == nil { ImageCache.shared.setObject(img, forKey: s as NSString) }
        let n = self.n
        let a = await Task.detached { Palette.analyze(img, n: n) }.value
        guard url == s else { return }
        image = img; colors = a.colors; dots = a.dots; field = a.field
    }

    var pal: Pal? { Pal.album(colors) }
}

/// The album colour field behind a page: cover-made gradient, darkened toward the bottom, with grain.
struct AlbumField: View {
    let field: UIImage?
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.03, blue: 0.06)
            if let field { Image(uiImage: field).resizable().scaledToFill() }
            LinearGradient(stops: [.init(color: .black.opacity(0.18), location: 0), .init(color: .black.opacity(0.4), location: 0.42),
                                   .init(color: .black.opacity(0.82), location: 1)], startPoint: .top, endPoint: .bottom)
            Image(uiImage: Palette.grain).resizable(resizingMode: .tile).opacity(0.07).blendMode(.overlay)
        }
        .drawingGroup()
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
