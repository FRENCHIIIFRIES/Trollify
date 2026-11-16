import Foundation

/// App state + Spotify Connect control. Audio plays on whichever Spotify device is selected
/// (e.g. the Spotify app on this iPad); this app is the interface.
@MainActor
final class Player: ObservableObject {
    let api: API
    @Published var state: PlayerState?
    @Published var devices: [Device] = []
    @Published var playlists: [Playlist] = []
    @Published var tracks: [Track] = []
    @Published var title = "LIBRARY"
    @Published var message: String?
    private var context: String?   // playlist uri of the list being shown

    init(api: API) { self.api = api }

    func start() async {
        await loadPlaylists()
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }
    }

    func refresh() async {
        do {
            let d = try await api.call("GET", "/me/player")
            if d.isEmpty { state = nil } else { state = try JSONDecoder().decode(PlayerState.self, from: d) }
            let dv: Devices = try await api.get("/me/player/devices")
            devices = dv.devices
            if message?.hasPrefix("Network") == true || message?.hasPrefix("Spotify says") == true { message = nil }
        } catch let e as APIError {
            message = e.status == 403 ? "Spotify says Premium is required, or your account isn't added to the dev app." : "Spotify error \(e.status)"
        } catch { message = "Network problem. Check Wi-Fi." }
    }

    func loadPlaylists() async {
        if let p: Page<Playlist> = try? await api.get("/me/playlists", ["limit": "50"]) { playlists = p.items }
    }

    func open(_ p: Playlist?) async {
        title = (p?.name ?? "Liked Songs").uppercased()
        context = p?.uri
        let path = p.map { "/playlists/\($0.id)/tracks" } ?? "/me/tracks"
        if let page: Page<TrackItem> = try? await api.get(path, ["limit": "100"]) {
            tracks = page.items.compactMap(\.track)
        }
    }

    func search(_ q: String) async {
        guard !q.isEmpty else { return }
        title = "SEARCH: \(q.uppercased())"
        context = nil
        if let r: SearchResult = try? await api.get("/search", ["q": q, "type": "track", "limit": "30"]) {
            tracks = r.tracks.items
        }
    }

    private func send(_ method: String, _ path: String, _ body: [String: Any]? = nil) async {
        do { _ = try await api.call(method, path, [:], body); message = nil }
        catch let e as APIError {
            message = e.status == 404 ? "No active device. Open Spotify on a device, then pick it with the device button." : "Spotify error \(e.status)"
        } catch { message = "Network problem. Check Wi-Fi." }
        await refresh()
    }

    func toggle() async { await send("PUT", state?.is_playing == true ? "/me/player/pause" : "/me/player/play") }
    func next() async { await send("POST", "/me/player/next") }
    func previous() async { await send("POST", "/me/player/previous") }
    func transfer(_ d: Device) async { if let id = d.id { await send("PUT", "/me/player", ["device_ids": [id], "play": true]) } }

    func play(_ t: Track) async {
        // No active device yet: wake the first available one (e.g. your PC) so the tap just works.
        if state?.device == nil, let d = devices.first { await transfer(d) }
        if let c = context { await send("PUT", "/me/player/play", ["context_uri": c, "offset": ["uri": t.uri]]) }
        else { await send("PUT", "/me/player/play", ["uris": [t.uri]]) }
    }
}
