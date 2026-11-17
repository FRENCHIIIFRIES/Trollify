import SwiftUI

/// Screenshot mode: launch with `-demo YES -screen now -orient landscape`.
/// Fills the app with made-up music so every screen can be captured in the simulator
/// without a Spotify account, laid out at the iPad Air 2's 1024x768 points.
enum Demo {
    static var on: Bool { UserDefaults.standard.bool(forKey: "demo") }
    static var screen: String? { UserDefaults.standard.string(forKey: "screen") }
    static var landscape: Bool { UserDefaults.standard.string(forKey: "orient") != "portrait" }

    private static func art(_ seed: String) -> [Img] {
        [Img(url: "https://frenchiiifries.github.io/Trollify/demo/\(seed).png", width: 640)]
    }

    private static func track(_ name: String, _ artist: String, _ seed: String, _ secs: Int) -> Track {
        Track(name: name, uri: "spotify:track:\(seed)", duration_ms: secs * 1000,
              artists: [Artist(name: artist)], album: Album(images: art(seed)))
    }

    static let tracks: [Track] = [
        track("Low Sun", "Marlow Kade", "cover", 228),
        track("Coastline Static", "Marlow Kade", "c2", 201),
        track("Paper Planets", "Juno Vale", "c3", 189),
        track("Glasshouse", "The Quiet Engines", "c4", 243),
        track("Night Bus Home", "Ola Brenner", "c5", 176),
        track("Saltwater Radio", "Juno Vale", "c6", 214),
        track("Neon Orchard", "Kite Theory", "c7", 232),
        track("Slow Motion Summer", "Ola Brenner", "c8", 198),
    ]

    static let playlists: [Playlist] = [
        Playlist(id: "p1", name: "Night Drive", uri: "spotify:playlist:p1", images: art("cover")),
        Playlist(id: "p2", name: "Focus", uri: "spotify:playlist:p2", images: art("c2")),
        Playlist(id: "p3", name: "Gym Rotation", uri: "spotify:playlist:p3", images: art("c3")),
        Playlist(id: "p4", name: "Old Favourites", uri: "spotify:playlist:p4", images: art("c5")),
        Playlist(id: "p5", name: "Rainy Sunday", uri: "spotify:playlist:p5", images: art("c6")),
        Playlist(id: "p6", name: "Road Trip 2026", uri: "spotify:playlist:p6", images: art("c7")),
    ]

    static let device = Device(id: "demo", name: "h3arth iPad", type: "Tablet", is_active: true)
    static let state = PlayerState(is_playing: true, item: tracks[0], progress_ms: 134_000, device: device)

    // Original placeholder lyrics, written for screenshots.
    static let lrc = """
    [00:00.00] We drove until the radio went quiet
    [02:08.00] Your hand out the window catching gold
    [02:12.00] Every mile marker blinking like a question
    [02:18.00] Stay with me until the low sun folds
    [02:24.00] Static on the dial, we sing it anyway
    [02:30.00] Nobody's listening but the road
    """
}

/// Lays the app out at exactly 1024x768 (landscape) or 768x1024 points and scales it to the simulator screen.
/// Landscape is drawn rotated; the screenshot step rotates the image back.
struct DemoFrame<Content: View>: View {
    let content: Content
    var body: some View {
        GeometryReader { g in
            let land = Demo.landscape
            let w: CGFloat = land ? 1024 : 768
            let h: CGFloat = land ? 768 : 1024
            let scale = (land ? g.size.height : g.size.width) / w
            content
                .frame(width: w, height: h)
                .scaleEffect(scale)
                .rotationEffect(.degrees(land ? 90 : 0))
                .position(x: g.size.width / 2, y: g.size.height / 2)
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
    }
}
