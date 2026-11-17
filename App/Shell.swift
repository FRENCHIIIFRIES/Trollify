import SwiftUI

/// The app frame, emb3r style: one glowing outline, a tab bar across the top, the page inside.
/// The player and an open album take the colours of their cover; everything else uses your colour.
struct Shell: View {
    @ObservedObject var auth: Auth
    @ObservedObject var updater: Updater
    @Environment(\.pal) private var pal
    @AppStorage("opt.pcWidth") private var pcWidth = 0.38
    @AppStorage("opt.albumColours") private var albumColours = true
    @AppStorage("opt.scanlines") private var scanlines = true
    @StateObject private var player: Player
    @StateObject private var lyrics = Lyrics()
    @StateObject private var web = WebStore()
    @StateObject private var tiles = TileStore()
    @StateObject private var nowArt = ArtModel()     // the song that's playing
    @StateObject private var albumArt = ArtModel()   // the playlist that's open on the music page
    @State private var current = Demo.screen.map { ["card", "boot"].contains($0) ? "player" : $0 } ?? "home"
    @State private var pcSide = false
    @State private var pcWide = false

    init(auth: Auth, updater: Updater) {
        self.auth = auth
        self.updater = updater
        _player = StateObject(wrappedValue: Player(api: API(auth)))
    }

    private var pages: [WebTab] { [.youtube, .instagram] + tiles.custom }

    /// The cover whose colours this page wears, if any.
    private var mood: ArtModel? {
        guard albumColours else { return nil }
        if current == "player", player.state?.item != nil { return nowArt }
        if current == "music", player.openPlaylist != nil { return albumArt }
        return nil
    }

    var body: some View {
        let moodPal = mood?.pal
        let p = moodPal ?? pal
        GeometryReader { g in
            ZStack {
                if let m = mood, moodPal != nil { AlbumField(field: m.field) }
                VStack(spacing: 0) {
                    TopBar(current: $current, pcSide: $pcSide, wide: g.size.width > 900, status: status)
                    Rectangle().fill(p.line).frame(height: 1)
                    HStack(spacing: 0) {
                        if !(pcSide && pcWide) {
                            content.id(current).transition(.opacity).frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        if pcSide {
                            Rectangle().fill(p.line).frame(width: 1)
                            WebPane(store: web, page: .pc, trailing: AnyView(
                                TermBtn(label: pcWide ? "half" : "full", size: 17) { withAnimation { pcWide.toggle() } }))
                                .frame(width: pcWide ? g.size.width - 30 : g.size.width * pcWidth)
                        }
                    }
                    if !["home", "player", "settings"].contains(current) { NowStrip(player: player, art: nowArt) }
                }
                if scanlines { Scanlines() }
            }
            .box(p.ph)
            .shadow(color: p.ph.opacity(0.25), radius: 10)
            .environment(\.pal, p)
        }
        .padding(12)
        .task { await player.start() }
        .task(id: player.state?.item?.uri) {
            await nowArt.load(player.state?.item?.art)
            if let t = player.state?.item { await lyrics.load(t); await player.loadQueue() }
        }
        .task(id: player.openPlaylist?.id) { await albumArt.load(player.openPlaylist?.art(min: 300)) }
    }

    private var status: String {
        if let d = player.state?.device, player.state?.is_playing == true { return "playing on \(d.name.lowercased())" }
        return auth.loggedIn ? "spotify linked" : "spotify not linked"
    }

    private func go(_ id: String) { withAnimation(.easeOut(duration: 0.18)) { current = id } }

    @ViewBuilder private var content: some View {
        switch current {
        case "home": HomeView(player: player, art: nowArt, tiles: tiles, go: go)
        case "music": MusicView(auth: auth, player: player)
        case "player": PlayerScreen(player: player, lyrics: lyrics, art: nowArt)
        case "settings": SettingsView(auth: auth, updater: updater, tiles: tiles, albumAccent: nowArt.colors.first)
        default:
            if let w = pages.first(where: { $0.id == current }) { WebPane(store: web, page: w) } else { Color.clear }
        }
    }
}

/// `● status    home music player youtube insta pc settings    9:41 bat 87%`
struct TopBar: View {
    @Environment(\.pal) private var pal
    @Binding var current: String
    @Binding var pcSide: Bool
    let wide: Bool
    let status: String
    private let tabs = [("home", "home"), ("music", "music"), ("player", "player"), ("yt", "youtube"), ("ig", "insta"), ("pc", "pc"), ("settings", "settings")]
    @State private var battery = 0

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Circle().fill(pal.ph).frame(width: 7, height: 7).shadow(color: pal.ph, radius: 4)
                if wide { Text(status).font(.term(17)).foregroundColor(pal.quiet).lineLimit(1) }
            }
            .frame(width: wide ? 220 : 14, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: wide ? 6 : 2) {
                ForEach(tabs, id: \.0) { id, name in
                    let on = id == "pc" ? pcSide : current == id
                    Button {
                        if id == "pc" { withAnimation { pcSide.toggle() } } else { withAnimation(.easeOut(duration: 0.18)) { current = id } }
                    } label: {
                        Text(name).font(.term(wide ? 20 : 18)).lineLimit(1)
                            .foregroundColor(on ? pal.bg : pal.quiet)
                            .padding(.horizontal, wide ? 9 : 6).padding(.vertical, 1)
                            .background(on ? pal.ph : Color.clear)
                    }
                }
            }
            .glow()
            Spacer(minLength: 0)
            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                Text("\(Self.time.string(from: ctx.date))  bat \(battery)%").font(.mono(12)).foregroundColor(pal.quiet).lineLimit(1)
            }
            .frame(width: wide ? 140 : 110, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            battery = max(Int(UIDevice.current.batteryLevel * 100), 0)
        }
    }

    private static let time: DateFormatter = { let f = DateFormatter(); f.dateFormat = "H:mm"; return f }()
}

/// Slim now-playing line at the foot of the music and web pages.
struct NowStrip: View {
    @Environment(\.pal) private var pal
    @ObservedObject var player: Player
    @ObservedObject var art: ArtModel

    var body: some View {
        if let t = player.state?.item {
            VStack(spacing: 0) {
                Rectangle().fill(pal.line).frame(height: 1)
                HStack(spacing: 14) {
                    DitherArt(dots: art.dots, n: art.n, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(t.name.lowercased()) // \(t.artistLine.lowercased())").font(.term(21)).foregroundColor(pal.ph).lineLimit(1)
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            let ms = player.nowMS(ctx.date), dur = max(t.duration_ms ?? 1, 1)
                            Text("\(clock(ms)) \(asciiBar(Double(ms) / Double(dur), 24)) \(clock(dur))").font(.mono(11)).foregroundColor(pal.quiet)
                        }
                    }
                    .glow()
                    Spacer()
                    TermBtn(label: "|<", size: 19) { Task { await player.previous() } }
                    TermBtn(label: player.state?.is_playing == true ? "pause" : "play", solid: true, size: 19) { Task { await player.toggle() } }
                    TermBtn(label: ">|", size: 19) { Task { await player.next() } }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
        }
    }
}
