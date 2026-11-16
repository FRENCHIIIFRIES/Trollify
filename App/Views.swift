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
            if auth.loggedIn { MainView(auth: auth) } else { LoginView(auth: auth) }
        }
        .overlay(alignment: .top) {
            if updater.available != nil {
                Button { updater.install() } label: {
                    Text("UPDATE AVAILABLE - TAP TO INSTALL").font(Theme.mono(12, .bold)).foregroundColor(.black)
                        .padding(.horizontal, 18).padding(.vertical, 10).background(Capsule().fill(Color.white))
                }.padding(.top, 8)
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
    var body: some View {
        VStack(spacing: 28) {
            HStack(spacing: 6) { ForEach(0..<5) { i in Circle().fill(i == 0 ? Theme.red : .white).frame(width: 12, height: 12) } }
            Text("TROLLIFY").font(Theme.mono(44, .bold)).tracking(8)
            Text("A fast Spotify controller. Premium required.").font(Theme.mono(14)).foregroundColor(Theme.dim)
            Button { auth.login() } label: {
                Text("CONNECT SPOTIFY").font(Theme.mono(16, .bold)).foregroundColor(.black)
                    .padding(.horizontal, 32).padding(.vertical, 16).background(Capsule().fill(Color.white))
            }
            if let e = auth.error {
                Text(e).font(Theme.mono(12)).foregroundColor(Theme.red).multilineTextAlignment(.center).padding(.horizontal, 40)
            }
            if Config.clientID.hasPrefix("PASTE") {
                Text("Set your Client ID in Config.swift first.").font(Theme.mono(12)).foregroundColor(Theme.red)
            }
        }
    }
}

struct MainView: View {
    @ObservedObject var auth: Auth
    @StateObject private var player: Player
    @State private var query = ""

    init(auth: Auth) {
        self.auth = auth
        _player = StateObject(wrappedValue: Player(api: API(auth)))
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 290).background(Theme.surface.opacity(0.5))
            VStack(spacing: 0) {
                if let m = player.message {
                    Text(m).font(Theme.mono(12)).foregroundColor(.white).frame(maxWidth: .infinity)
                        .padding(10).background(Theme.red)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Text(player.title).font(Theme.mono(28, .bold)).tracking(3).padding(24)
                        ForEach(Array(player.tracks.enumerated()), id: \.offset) { i, t in
                            Button { Task { await player.play(t) } } label: { row(i, t) }
                        }
                    }.padding(.bottom, 24)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { NowPlaying(player: player) }
        .task { await player.start() }
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
        }.padding(16)
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
        }.padding(.horizontal, 24).padding(.vertical, 8)
    }
}

struct NowPlaying: View {
    @ObservedObject var player: Player
    var body: some View {
        let s = player.state
        let item = s?.item
        VStack(spacing: 10) {
            GeometryReader { g in
                let frac = CGFloat(s?.progress_ms ?? 0) / CGFloat(max(item?.duration_ms ?? 1, 1))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(Theme.red).frame(width: g.size.width * min(max(frac, 0), 1))
                }
            }.frame(height: 3)
            HStack(spacing: 16) {
                Art(url: item?.art, size: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item?.name ?? "Nothing playing").font(Theme.mono(15, .bold)).lineLimit(1)
                    Text(item?.artistLine ?? "Pick a song or device").font(Theme.mono(12)).foregroundColor(Theme.dim).lineLimit(1)
                }
                Spacer()
                ctl("backward.fill") { await player.previous() }
                Button { Task { await player.toggle() } } label: {
                    Image(systemName: s?.is_playing == true ? "pause.fill" : "play.fill")
                        .font(.system(size: 22)).foregroundColor(.black).frame(width: 52, height: 52)
                        .background(Circle().fill(Color.white))
                }
                ctl("forward.fill") { await player.next() }
                Menu {
                    if player.devices.isEmpty { Button("No devices - open Spotify on your PC and press play") {}.disabled(true) }
                    ForEach(player.devices, id: \.ident) { d in
                        Button((d.is_active ? "• " : "") + d.name) { Task { await player.transfer(d) } }
                    }
                } label: {
                    Image(systemName: "hifispeaker.fill").font(.system(size: 20)).foregroundColor(Theme.red).frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
    }

    private func ctl(_ icon: String, _ action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Image(systemName: icon).font(.system(size: 20)).foregroundColor(.white).frame(width: 44, height: 44)
        }
    }
}

@main
struct TrollifyApp: App {
    var body: some Scene { WindowGroup { RootView().preferredColorScheme(.dark) } }
}
