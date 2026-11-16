import SwiftUI

/// App frame: side rail of dot-matrix tabs, content, optional PC mirror panel, mini player.
struct Shell: View {
    @ObservedObject var auth: Auth
    @StateObject private var player: Player
    @StateObject private var lyrics = Lyrics()
    @StateObject private var web = WebStore()
    @StateObject private var tiles = TileStore()
    @State private var current = "home"
    @State private var pcSide = false
    @State private var pcWide = false

    init(auth: Auth) {
        self.auth = auth
        _player = StateObject(wrappedValue: Player(api: API(auth)))
    }

    private var pages: [WebTab] { [.youtube, .instagram] + tiles.custom }

    var body: some View {
        GeometryReader { g in
            HStack(spacing: 0) {
                rail
                Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1)
                if !(pcSide && pcWide) { content.frame(maxWidth: .infinity, maxHeight: .infinity) }
                if pcSide {
                    Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1)
                    WebPane(store: web, page: .pc, trailing: AnyView(
                        Button { withAnimation { pcWide.toggle() } } label: {
                            Image(systemName: pcWide ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 16)).foregroundColor(.white).frame(width: 34, height: 30)
                        }))
                        .frame(width: pcWide ? g.size.width - 85 : g.size.width * 0.38)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if current != "now" { MiniPlayer(player: player) { current = "now" } }
        }
        .task { await player.start() }
    }

    @ViewBuilder private var content: some View {
        switch current {
        case "home": HomeView(player: player, tiles: tiles) { current = $0 }
        case "music": MusicView(auth: auth, player: player)
        case "now": NowScreen(player: player, lyrics: lyrics)
        default:
            if let p = pages.first(where: { $0.id == current }) { WebPane(store: web, page: p) }
            else { Color.clear }
        }
    }

    private var rail: some View {
        VStack(spacing: 6) {
            DotText(text: "TRL", dot: 3, color: Theme.red).padding(.vertical, 18)
            railButton("home", "HOM")
            railButton("music", "MUS")
            railButton("now", "NOW")
            ForEach(pages) { p in railButton(p.id, p.code) }
            Spacer()
            Button { withAnimation { pcSide.toggle(); if !pcSide { pcWide = false } } } label: {
                DotText(text: "PC", dot: 3, color: pcSide ? .white : Theme.dim)
                    .frame(width: 70, height: 48)
                    .background(RoundedRectangle(cornerRadius: 10).fill(pcSide ? Theme.red : Color.clear))
            }
            .padding(.bottom, 14)
        }
        .frame(width: 84)
        .background(Theme.surface.opacity(0.6))
    }

    private func railButton(_ id: String, _ code: String) -> some View {
        Button { current = id } label: {
            DotText(text: String(code.prefix(3)), dot: 3, color: current == id ? .white : Theme.dim)
                .frame(width: 70, height: 48)
                .background(RoundedRectangle(cornerRadius: 10).fill(current == id ? Theme.red : Color.clear))
        }
    }
}

struct MiniPlayer: View {
    @ObservedObject var player: Player
    var open: () -> Void

    var body: some View {
        if let t = player.state?.item {
            HStack(spacing: 14) {
                Art(url: t.art, size: 44)
                VStack(alignment: .leading, spacing: 6) {
                    DotMarquee(text: t.name, cols: 24, dot: 2.8)
                    DotText(text: String(t.artistLine.dotSafe.prefix(36)), dot: 2, color: Theme.dim)
                }
                Spacer()
                Button { Task { await player.previous() } } label: { icon("backward.fill") }
                Button { Task { await player.toggle() } } label: { icon(player.state?.is_playing == true ? "pause.fill" : "play.fill") }
                Button { Task { await player.next() } } label: { icon("forward.fill") }
            }
            .padding(.horizontal, 18).padding(.vertical, 8)
            .background(Theme.surface.ignoresSafeArea(edges: .bottom))
            .onTapGesture(perform: open)
        }
    }

    private func icon(_ n: String) -> some View {
        Image(systemName: n).font(.system(size: 20)).foregroundColor(.white).frame(width: 44, height: 44)
    }
}
