import Foundation

struct Img: Decodable, Equatable { let url: String; let width: Int? }
struct Artist: Decodable, Equatable { let name: String }
struct Album: Decodable, Equatable { let images: [Img]? }
struct Track: Decodable, Equatable {
    let name: String
    let uri: String
    let duration_ms: Int?
    let artists: [Artist]?   // nil for podcast episodes
    let album: Album?
    var artistLine: String { (artists ?? []).map(\.name).joined(separator: ", ") }
    var art: String? { album?.images?.first?.url }
    /// Smallest cover that is still at least `px` wide (keeps lists light on memory).
    func art(min px: Int) -> String? {
        let imgs = (album?.images ?? []).sorted { ($0.width ?? 0) < ($1.width ?? 0) }
        return (imgs.first { ($0.width ?? 640) >= px } ?? imgs.last)?.url
    }
}
struct Playlist: Decodable, Identifiable { let id: String; let name: String; let uri: String; let images: [Img]? }
struct Page<T: Decodable>: Decodable { let items: [T] }
struct TrackItem: Decodable { let track: Track? }
struct Device: Decodable, Equatable { let id: String?; let name: String; let type: String; let is_active: Bool; var ident: String { id ?? name } }
struct Devices: Decodable { let devices: [Device] }
struct PlayerState: Decodable, Equatable { let is_playing: Bool; let item: Track?; let progress_ms: Int?; let device: Device? }
struct SearchResult: Decodable { let tracks: Page<Track> }
struct APIError: Error { let status: Int }

final class API {
    let auth: Auth
    init(_ auth: Auth) { self.auth = auth }

    func call(_ method: String, _ path: String, _ q: [String: String] = [:], _ body: [String: Any]? = nil) async throws -> Data {
        var c = URLComponents(string: "https://api.spotify.com/v1" + path)!
        if !q.isEmpty { c.queryItems = q.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var r = URLRequest(url: c.url!)
        r.httpMethod = method
        let t = try await auth.token()
        r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        if let body {
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, resp) = try await URLSession.shared.data(for: r)
        if let h = resp as? HTTPURLResponse, h.statusCode >= 400 { throw APIError(status: h.statusCode) }
        return data
    }

    func get<T: Decodable>(_ path: String, _ q: [String: String] = [:]) async throws -> T {
        try JSONDecoder().decode(T.self, from: try await call("GET", path, q))
    }
}
