import Foundation

struct LyricLine { let t: Double; let text: String }

/// Time-synced lyrics from LRCLIB (free public lyrics database).
@MainActor
final class Lyrics: ObservableObject {
    @Published var lines: [LyricLine] = []
    @Published var status = ""
    private var loaded: String?

    private struct Resp: Decodable { let syncedLyrics: String?; let plainLyrics: String? }

    func load(_ t: Track) async {
        guard loaded != t.uri else { return }
        if Demo.on { loaded = t.uri; lines = Self.parse(Demo.lrc); status = ""; return }
        loaded = t.uri; lines = []; status = "SEARCHING LYRICS"
        var c = URLComponents(string: "https://lrclib.net/api/get")!
        c.queryItems = [
            .init(name: "track_name", value: t.name),
            .init(name: "artist_name", value: t.artists?.first?.name ?? ""),
            .init(name: "duration", value: String((t.duration_ms ?? 0) / 1000)),
        ]
        var req = URLRequest(url: c.url!)
        req.setValue("Trollify/1.0", forHTTPHeaderField: "User-Agent")
        let result = try? await URLSession.shared.data(for: req)
        guard loaded == t.uri else { return }   // track changed while waiting
        guard let (data, resp) = result, (resp as? HTTPURLResponse)?.statusCode == 200,
              let r = try? JSONDecoder().decode(Resp.self, from: data) else { status = "NO LYRICS FOUND"; return }
        if let s = r.syncedLyrics, !s.isEmpty {
            lines = Self.parse(s)
            status = lines.isEmpty ? "NO LYRICS FOUND" : ""
        } else {
            status = r.plainLyrics == nil ? "NO LYRICS FOUND" : "LYRICS NOT SYNCED"
        }
    }

    /// "[01:23.45] text" lines.
    static func parse(_ lrc: String) -> [LyricLine] {
        guard let re = try? NSRegularExpression(pattern: #"^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$"#) else { return [] }
        return lrc.split(separator: "\n").compactMap { line in
            let s = String(line), ns = s as NSString
            guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
            let mins = Double(ns.substring(with: m.range(at: 1))) ?? 0
            let secs = Double(ns.substring(with: m.range(at: 2))) ?? 0
            return LyricLine(t: mins * 60 + secs, text: ns.substring(with: m.range(at: 3)))
        }
    }

    /// The lines around a playback position, and how far through the current line we are (0...1),
    /// spread evenly over its words. shortcut: LRC only times lines, so word timing is an estimate.
    func karaoke(atMS ms: Int) -> (prev: String, cur: String, frac: Double, next: [String]) {
        let t = Double(ms) / 1000
        guard !lines.isEmpty else { return ("", "", 0, []) }
        guard let i = lines.lastIndex(where: { $0.t <= t }) else { return ("", "", 0, lines.prefix(2).map(\.text)) }
        let end = i + 1 < lines.count ? lines[i + 1].t : lines[i].t + 4
        let frac = max(0, min(1, (t - lines[i].t) / max(end - lines[i].t, 0.5)))
        return (i > 0 ? lines[i - 1].text : "", lines[i].text, frac, Array(lines[(i + 1)...].prefix(2)).map(\.text))
    }

    /// (current line, next line) for a playback position.
    func pair(atMS ms: Int) -> (String, String) {
        guard !lines.isEmpty else { return ("", "") }
        let t = Double(ms) / 1000
        guard let i = lines.lastIndex(where: { $0.t <= t }) else { return ("", lines[0].text) }
        return (lines[i].text, i + 1 < lines.count ? lines[i + 1].text : "")
    }
}
