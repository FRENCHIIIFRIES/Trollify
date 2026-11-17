import SwiftUI

enum ImageCache { static let shared: NSCache<NSString, UIImage> = { let c = NSCache<NSString, UIImage>(); c.countLimit = 120; return c }() }

/// Cover art with an in-memory cache and a short fade-in (AsyncImage re-downloads while scrolling).
struct Art: View {
    @Environment(\.pal) private var pal
    let url: String?
    var size: CGFloat
    @State private var img: UIImage?
    var body: some View {
        ZStack {
            pal.hover
            if let img { Image(uiImage: img).resizable().scaledToFill().transition(.opacity) }
        }
        .frame(width: size, height: size).clipped()
        .task(id: url) { await load() }
    }
    private func load() async {
        guard let s = url else { img = nil; return }
        if let c = ImageCache.shared.object(forKey: s as NSString) { img = c; return }
        guard let u = URL(string: s), let (d, _) = try? await URLSession.shared.data(from: u), let i = UIImage(data: d) else { return }
        ImageCache.shared.setObject(i, forKey: s as NSString)
        withAnimation(.easeIn(duration: 0.2)) { img = i }
    }
}

struct RootView: View {
    @StateObject var auth = Auth()
    @StateObject var updater = Updater()
    @AppStorage("opt.autoupdate") private var autoUpdate = true
    @AppStorage("opt.color") private var hex = Pal.phosphor
    @AppStorage("opt.boot") private var bootOn = true
    @State private var booting = true

    var body: some View {
        let pal = Pal(UIColor(hex: hex) ?? UIColor(hex: Pal.phosphor)!)
        let app = ZStack {
            Shell(auth: auth, updater: updater)
            if booting && (Demo.on ? Demo.screen == "boot" : bootOn) {
                BootView { withAnimation(.easeOut(duration: 0.4)) { booting = false } }.transition(.opacity)
            }
        }
        ZStack {
            pal.bg.ignoresSafeArea()
            if Demo.on { DemoFrame(content: app) } else { app }
        }
        .environment(\.pal, pal)
        .buttonStyle(PressStyle())
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            if updater.available != nil && !booting {
                TermBtn(label: "update ready, tap to install", solid: true) { updater.install() }.padding(.top, 6).environment(\.pal, pal)
            }
        }
        .task {
            while !Task.isCancelled {
                if autoUpdate && !Demo.on { await updater.check() }
                try? await Task.sleep(nanoseconds: 3_600_000_000_000)
            }
        }
    }
}

struct LoginView: View {
    @Environment(\.pal) private var pal
    @ObservedObject var auth: Auth
    @State private var scanning = false
    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 16) { EmberMark(size: 70); Wordmark(size: 10) }
            Text("// connect spotify (premium) to browse and control your music").font(.term(21)).foregroundColor(pal.quiet)
            HStack(spacing: 12) {
                TermBtn(label: "connect spotify", solid: true) { auth.login() }
                TermBtn(label: "scan qr from pc") { scanning = true }
            }
            Text("// stuck on spotify's page? on your pc open frenchiiifries.github.io/Trollify/login.html")
                .font(.term(18)).foregroundColor(pal.dim).multilineTextAlignment(.center)
            if let e = auth.error { Text("! " + e).font(.term(19)).foregroundColor(pal.hi).multilineTextAlignment(.center).padding(.horizontal, 40) }
        }
        .glow()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $scanning) {
            QRScanner { code in scanning = false; Task { await auth.pair(code) } }.ignoresSafeArea()
        }
    }
}

/// Library on the left, the open playlist on the right; the playlist's cover sets the page colours.
struct MusicView: View {
    @Environment(\.pal) private var pal
    @ObservedObject var auth: Auth
    @ObservedObject var player: Player
    @State private var query = ""

    var body: some View {
        if !auth.loggedIn {
            LoginView(auth: auth)
        } else {
            HStack(spacing: 0) {
                library.frame(width: 250)
                Rectangle().fill(pal.line).frame(width: 1)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        search
                        if let m = player.message { Text("! " + m).font(.term(19)).foregroundColor(pal.hi).padding(.top, 10) }
                        header
                        columns
                        ForEach(Array(player.tracks.enumerated()), id: \.offset) { i, t in
                            Button { Task { await player.play(t) } } label: { row(i, t) }
                        }
                    }
                    .padding(.horizontal, 24).padding(.vertical, 16)
                }
            }
        }
    }

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text("// library").font(.term(18)).foregroundColor(pal.dim).padding(.horizontal, 18).padding(.bottom, 6)
                libraryRow(nil, "liked songs", art: nil)
                ForEach(player.playlists) { p in libraryRow(p, p.name, art: p.art(min: 60)) }
                Button("[ log out ]") { auth.logout() }.font(.term(18)).foregroundColor(pal.dim).padding(18)
            }
            .padding(.vertical, 16)
        }
        .background(Color.black.opacity(0.18))
    }

    private func libraryRow(_ p: Playlist?, _ name: String, art: String?) -> some View {
        let on = player.openPlaylist?.id == p?.id && (p != nil || player.title == "Liked Songs")
        return Button { Task { await player.open(p) } } label: {
            HStack(spacing: 10) {
                Text(on ? ">" : " ").font(.term(22)).foregroundColor(pal.ph).frame(width: 10)
                if p == nil { Text("♥").font(.term(26)).foregroundColor(pal.ph).frame(width: 30, height: 30).box(pal.line) } else { Art(url: art, size: 30) }
                Text(name.lowercased()).font(.term(22)).foregroundColor(on ? pal.hi : pal.quiet).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(on ? pal.hover : Color.clear)
            .glow()
        }
    }

    private var search: some View {
        HStack(spacing: 10) {
            Text(">").font(.term(24)).foregroundColor(pal.ph)
            TextField("", text: $query)
                .font(.term(22)).foregroundColor(pal.hi).accentColor(pal.ph)
                .placeholder(when: query.isEmpty) { Text("search songs, artists, albums...").font(.term(22)).foregroundColor(pal.dim) }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.black.opacity(0.22)).box(pal.ph)
                .onSubmit { Task { await player.search(query) } }
            TermBtn(label: "find") { Task { await player.search(query) } }
        }
        .glow()
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 22) {
            if let p = player.openPlaylist {
                Art(url: p.art(min: 300), size: 150).shadow(color: .black.opacity(0.5), radius: 18, y: 12).box(pal.lineStrong)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(player.title.lowercased()).font(.term(58)).foregroundColor(pal.hi).lineLimit(1).minimumScaleFactor(0.5).glow(true)
                Text("// \(player.tracks.count) songs, \(player.tracks.compactMap(\.duration_ms).reduce(0, +) / 60000) min")
                    .font(.term(20)).foregroundColor(pal.quiet)
                HStack(spacing: 10) {
                    TermBtn(label: "play", solid: true) { Task { await player.playAll(shuffle: false) } }
                    TermBtn(label: "shuffle") { Task { await player.playAll(shuffle: true) } }
                }
                .padding(.top, 6)
            }
        }
        .padding(.top, 22).padding(.bottom, 16)
    }

    private var columns: some View {
        HStack {
            Text("#").frame(width: 40, alignment: .leading)
            Text("title")
            Spacer()
            Text("artist").frame(width: 230, alignment: .leading)
            Text("time").frame(width: 54, alignment: .trailing)
        }
        .font(.mono(11)).foregroundColor(pal.dim).padding(.horizontal, 10).padding(.bottom, 4)
        .overlay(alignment: .bottom) { Rectangle().fill(pal.lineStrong).frame(height: 1) }
    }

    private func row(_ i: Int, _ t: Track) -> some View {
        let playing = player.state?.item?.uri == t.uri
        return HStack {
            Text(playing ? "♪" : String(format: "%02d", i + 1)).font(.mono(13)).frame(width: 40, alignment: .leading)
            Text(t.name.lowercased()).font(.term(23)).lineLimit(1)
            Spacer()
            Text(t.artistLine.lowercased()).font(.term(23)).lineLimit(1).frame(width: 230, alignment: .leading)
                .foregroundColor(playing ? pal.bg : pal.quiet)
            Text(clock(t.duration_ms ?? 0)).font(.mono(12)).frame(width: 54, alignment: .trailing)
        }
        .foregroundColor(playing ? pal.bg : pal.ph)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Group { if playing { LinearGradient(colors: pal.fill, startPoint: .leading, endPoint: .trailing) } })
        .overlay(alignment: .bottom) { Rectangle().fill(pal.line).frame(height: 1) }
        .glow()
    }
}

@main
struct TrollifyApp: App {
    var body: some Scene { WindowGroup { RootView() } }
}
