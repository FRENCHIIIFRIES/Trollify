import SwiftUI

enum Theme {
    static let bg = Color(red: 0.03, green: 0.03, blue: 0.035)
    static let surface = Color(red: 0.11, green: 0.11, blue: 0.14)
    static let card = Color.white.opacity(0.07)
    static let red = Color(red: 1.0, green: 0.27, blue: 0.25)
    static let dim = Color.white.opacity(0.55)
    static func mono(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font { .system(size: size, weight: w, design: .rounded) }   // name kept from the old look; it is the rounded UI font now
}

enum ImageCache { static let shared: NSCache<NSString, UIImage> = { let c = NSCache<NSString, UIImage>(); c.countLimit = 120; return c }() }

/// Cover art with an in-memory cache and a short fade-in (AsyncImage re-downloads while scrolling).
struct Art: View {
    let url: String?
    var size: CGFloat
    var radius: CGFloat = 10
    @State private var img: UIImage?
    var body: some View {
        ZStack {
            Theme.surface
            if let img { Image(uiImage: img).resizable().scaledToFill().transition(.opacity) }
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
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

/// Gentle press feedback on every button.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct RootView: View {
    @StateObject var auth = Auth()
    @StateObject var updater = Updater()
    @AppStorage("opt.autoupdate") private var autoUpdate = true
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.09), Color(red: 0.10, green: 0.06, blue: 0.13), .black],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            if Demo.on { DemoFrame(content: Shell(auth: auth, updater: updater)) } else { Shell(auth: auth, updater: updater) }
        }
        .buttonStyle(PressStyle())
        .overlay(alignment: .top) {
            if updater.available != nil {
                Button { updater.install() } label: {
                    DotText(text: "UPDATE AVAILABLE - TAP TO INSTALL", dot: 2.6, color: .black)
                        .padding(.horizontal, 18).padding(.vertical, 10).background(Capsule().fill(Color.white))
                }
                .padding(.top, 8)
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
    @ObservedObject var auth: Auth
    @State private var scanning = false
    var body: some View {
        VStack(spacing: 26) {
            HStack(spacing: 6) { ForEach(0..<5) { i in Circle().fill(i == 0 ? Theme.red : .white).frame(width: 12, height: 12) } }
            DotText(text: "TROLLIFY", dot: 8)
            Text("Connect Spotify (Premium) to browse and control music.").font(Theme.mono(14)).foregroundColor(Theme.dim)
            Button { auth.login() } label: {
                Text("CONNECT SPOTIFY").font(Theme.mono(16, .bold)).foregroundColor(.black)
                    .padding(.horizontal, 32).padding(.vertical, 16).background(Capsule().fill(Color.white))
            }
            Button { scanning = true } label: {
                Text("SCAN QR FROM PC").font(Theme.mono(14, .bold)).foregroundColor(.white)
                    .padding(.horizontal, 28).padding(.vertical, 14).overlay(Capsule().stroke(Color.white, lineWidth: 1.5))
            }
            Text("Stuck on Spotify's page? On your PC open\nfrenchiiifries.github.io/Trollify/login.html")
                .font(Theme.mono(11)).foregroundColor(Theme.dim).multilineTextAlignment(.center)
            if let e = auth.error {
                Text(e).font(Theme.mono(12)).foregroundColor(Theme.red).multilineTextAlignment(.center).padding(.horizontal, 40)
            }
            if Config.clientID.hasPrefix("PASTE") {
                Text("Set your Client ID in Config.swift first.").font(Theme.mono(12)).foregroundColor(Theme.red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $scanning) {
            QRScanner { code in scanning = false; Task { await auth.pair(code) } }.ignoresSafeArea()
        }
    }
}

/// Spotify library: a shelf of playlist covers, then the track list.
struct MusicView: View {
    @ObservedObject var auth: Auth
    @ObservedObject var player: Player
    @State private var query = ""

    var body: some View {
        if !auth.loggedIn {
            LoginView(auth: auth)
        } else {
            VStack(spacing: 0) {
                if let m = player.message {
                    Text(m).font(Theme.mono(12, .semibold)).foregroundColor(.white).frame(maxWidth: .infinity)
                        .padding(10).background(Theme.red)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        header
                        shelf
                        Text(player.title).font(Theme.mono(22, .bold)).padding(.horizontal, 28).padding(.top, 26).padding(.bottom, 8)
                        ForEach(Array(player.tracks.enumerated()), id: \.offset) { i, t in
                            Button { Task { await player.play(t) } } label: { row(i, t) }
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text("Music").font(.system(size: 38, weight: .bold, design: .rounded))
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(Theme.dim)
                TextField("Search songs", text: $query).font(Theme.mono(15))
                    .onSubmit { Task { await player.search(query) } }
            }
            .padding(.horizontal, 14).padding(.vertical, 11).frame(width: 300)
            .background(Capsule().fill(Theme.card))
        }
        .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 18)
    }

    private var shelf: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                shelfCard("Liked Songs", art: nil) { await player.open(nil) }
                ForEach(player.playlists) { p in
                    shelfCard(p.name, art: p.art(min: 200)) { await player.open(p) }
                }
            }
            .padding(.horizontal, 28)
        }
    }

    private func shelfCard(_ name: String, art: String?, _ open: @escaping () async -> Void) -> some View {
        Button { Task { await open() } } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    if art == nil {
                        LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: "heart.fill").font(.system(size: 36)).foregroundColor(.white)
                    } else {
                        Art(url: art, size: 136, radius: 18)
                    }
                }
                .frame(width: 136, height: 136).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(name).font(Theme.mono(13, .semibold)).foregroundColor(.white).lineLimit(2)
                    .multilineTextAlignment(.leading).frame(width: 136, alignment: .leading)
            }
        }
    }

    private func row(_ i: Int, _ t: Track) -> some View {
        let playing = player.state?.item?.uri == t.uri
        return HStack(spacing: 14) {
            Art(url: t.art(min: 100), size: 52, radius: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(t.name).font(Theme.mono(16, .semibold)).foregroundColor(playing ? Theme.red : .white).lineLimit(1)
                Text(t.artistLine).font(Theme.mono(13)).foregroundColor(Theme.dim).lineLimit(1)
            }
            Spacer()
            if playing { Image(systemName: "waveform").foregroundColor(Theme.red) }
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(playing ? Theme.red.opacity(0.12) : Color.clear))
        .padding(.horizontal, 14)
    }
}

@main
struct TrollifyApp: App {
    var body: some Scene { WindowGroup { RootView().preferredColorScheme(.dark) } }
}
