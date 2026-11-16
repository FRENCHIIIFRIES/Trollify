import SwiftUI

/// App frame: icon dock on the left, content, optional PC mirror panel, floating mini player.
struct Shell: View {
    @ObservedObject var auth: Auth
    @ObservedObject var updater: Updater
    @AppStorage("opt.pcWidth") private var pcWidth = 0.38
    @StateObject private var player: Player
    @StateObject private var lyrics = Lyrics()
    @StateObject private var web = WebStore()
    @StateObject private var tiles = TileStore()
    @State private var current = "home"
    @State private var pcSide = false
    @State private var pcWide = false

    init(auth: Auth, updater: Updater) {
        self.auth = auth
        self.updater = updater
        _player = StateObject(wrappedValue: Player(api: API(auth)))
    }

    private var pages: [WebTab] { [.youtube, .instagram] + tiles.custom }

    var body: some View {
        GeometryReader { g in
            HStack(spacing: 0) {
                dock
                if !(pcSide && pcWide) {
                    content.id(current).transition(.opacity)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if pcSide {
                    WebPane(store: web, page: .pc, trailing: AnyView(
                        Button { withAnimation { pcWide.toggle() } } label: {
                            Image(systemName: pcWide ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 16)).foregroundColor(.white).frame(width: 34, height: 30)
                        }))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.vertical, 10).padding(.trailing, 10)
                        .frame(width: pcWide ? g.size.width - 100 : g.size.width * pcWidth)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if current != "now" { MiniPlayer(player: player) { withAnimation(.easeOut(duration: 0.2)) { current = "now" } } }
        }
        .task { await player.start() }
    }

    @ViewBuilder private var content: some View {
        switch current {
        case "home": HomeView(player: player, tiles: tiles) { id in withAnimation(.easeOut(duration: 0.2)) { current = id } }
        case "music": MusicView(auth: auth, player: player)
        case "now": NowScreen(player: player, lyrics: lyrics)
        case "settings": SettingsView(auth: auth, updater: updater, tiles: tiles)
        default:
            if let p = pages.first(where: { $0.id == current }) { WebPane(store: web, page: p) }
            else { Color.clear }
        }
    }

    // MARK: dock

    private var dock: some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                Circle().fill(Theme.red).frame(width: 6, height: 6)
                Circle().fill(Color.white).frame(width: 6, height: 6)
                Circle().fill(Color.white.opacity(0.5)).frame(width: 6, height: 6)
            }
            .padding(.top, 22).padding(.bottom, 14)
            item("home", "house.fill", "Home")
            item("music", "music.note.list", "Music")
            item("now", "waveform", "Player")
            ForEach(pages) { p in item(p.id, symbol(p), label(p)) }
            Spacer()
            item("settings", "gearshape.fill", "Settings")
            Button { withAnimation { pcSide.toggle(); if !pcSide { pcWide = false } } } label: {
                dockLabel("desktopcomputer", "PC", pcSide)
            }
            .padding(.bottom, 12)
        }
        .frame(width: 92)
        .background(Color.white.opacity(0.04))
    }

    private func symbol(_ p: WebTab) -> String { p.id == "yt" ? "play.rectangle.fill" : p.id == "ig" ? "camera.fill" : "globe" }
    private func label(_ p: WebTab) -> String { p.id == "yt" ? "YouTube" : p.id == "ig" ? "Instagram" : p.title.capitalized }

    private func item(_ id: String, _ icon: String, _ text: String) -> some View {
        Button { withAnimation(.easeOut(duration: 0.2)) { current = id } } label: { dockLabel(icon, text, current == id) }
    }

    private func dockLabel(_ icon: String, _ text: String, _ selected: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 21, weight: .semibold))
            Text(text).font(.system(size: 10, weight: .semibold, design: .rounded)).lineLimit(1)
        }
        .foregroundColor(selected ? Theme.red : Theme.dim)
        .frame(width: 76, height: 58)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(selected ? Theme.red.opacity(0.16) : Color.clear))
    }
}

/// Floating glass mini player.
struct MiniPlayer: View {
    @ObservedObject var player: Player
    var open: () -> Void

    var body: some View {
        if let t = player.state?.item {
            HStack(spacing: 14) {
                Art(url: t.art(min: 100), size: 48, radius: 10)
                VStack(alignment: .leading, spacing: 3) {
                    Text(t.name).font(Theme.mono(15, .semibold)).lineLimit(1)
                    Text(t.artistLine).font(Theme.mono(12)).foregroundColor(Theme.dim).lineLimit(1)
                }
                Spacer()
                Button { Task { await player.previous() } } label: { icon("backward.fill") }
                Button { Task { await player.toggle() } } label: { icon(player.state?.is_playing == true ? "pause.fill" : "play.fill") }
                Button { Task { await player.next() } } label: { icon("forward.fill") }
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 16).padding(.bottom, 8)
            .contentShape(Rectangle())
            .onTapGesture(perform: open)
        }
    }

    private func icon(_ n: String) -> some View {
        Image(systemName: n).font(.system(size: 20)).foregroundColor(.white).frame(width: 44, height: 44)
    }
}
