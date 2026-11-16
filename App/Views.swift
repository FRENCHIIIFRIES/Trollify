import SwiftUI

enum Theme {
    static let bg = Color(red: 0.03, green: 0.03, blue: 0.035)
    static let surface = Color(red: 0.09, green: 0.09, blue: 0.10)
    static let red = Color(red: 0.84, green: 0.10, blue: 0.12)
    static let dim = Color.white.opacity(0.55)
    static func mono(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font { .system(size: size, weight: w, design: .monospaced) }
}

struct Art: View {
    let url: String?
    var size: CGFloat
    var body: some View {
        AsyncImage(url: url.flatMap(URL.init)) { img in img.resizable().scaledToFill() } placeholder: { Theme.surface }
            .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct RootView: View {
    @StateObject var auth = Auth()
    @StateObject var updater = Updater()
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            Shell(auth: auth)
        }
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
                await updater.check()
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

/// Spotify library: playlists on the left, tracks on the right.
struct MusicView: View {
    @ObservedObject var auth: Auth
    @ObservedObject var player: Player
    @State private var query = ""

    var body: some View {
        if !auth.loggedIn {
            LoginView(auth: auth)
        } else {
            HStack(spacing: 0) {
                sidebar.frame(width: 250).background(Theme.surface.opacity(0.5))
                VStack(spacing: 0) {
                    if let m = player.message {
                        Text(m).font(Theme.mono(12)).foregroundColor(.white).frame(maxWidth: .infinity)
                            .padding(10).background(Theme.red)
                    }
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            DotText(text: String(player.title.dotSafe.prefix(28)), dot: 4).padding(24)
                            ForEach(Array(player.tracks.enumerated()), id: \.offset) { i, t in
                                Button { Task { await player.play(t) } } label: { row(i, t) }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Search songs", text: $query)
                .font(Theme.mono(15)).padding(12).background(Theme.surface).cornerRadius(12)
                .onSubmit { Task { await player.search(query) } }
            sideButton("LIKED SONGS") { await player.open(nil) }
            Text("PLAYLISTS").font(Theme.mono(11)).foregroundColor(Theme.dim).padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(player.playlists) { p in sideButton(p.name) { await player.open(p) } }
                }
            }
            Button("Log out") { auth.logout() }.font(Theme.mono(12)).foregroundColor(Theme.dim)
        }
        .padding(16)
    }

    private func sideButton(_ text: String, _ action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(text).font(Theme.mono(14)).foregroundColor(.white).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
        }
    }

    private func row(_ i: Int, _ t: Track) -> some View {
        let playing = player.state?.item?.uri == t.uri
        return HStack(spacing: 14) {
            Text(String(format: "%02d", i + 1)).font(Theme.mono(13)).foregroundColor(playing ? Theme.red : Theme.dim).frame(width: 28)
            Art(url: t.art, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(t.name).font(Theme.mono(15, .bold)).foregroundColor(playing ? Theme.red : .white).lineLimit(1)
                Text(t.artistLine).font(Theme.mono(12)).foregroundColor(Theme.dim).lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 24).padding(.vertical, 8)
    }
}

@main
struct TrollifyApp: App {
    var body: some Scene { WindowGroup { RootView().preferredColorScheme(.dark) } }
}
