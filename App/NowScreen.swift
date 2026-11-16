import SwiftUI

/// Full-screen player: album art + its colours, dot-matrix title, synced lyrics, LED meter.
struct NowScreen: View {
    @ObservedObject var player: Player
    @ObservedObject var lyrics: Lyrics
    @StateObject private var art = ArtModel()
    @State private var fullArt = false

    var body: some View {
        GeometryReader { g in
            ZStack {
                backdrop(g.size)
                Scanlines()
                if let t = player.state?.item { layout(g.size, t) } else { idle }
                VStack {
                    HStack {
                        Spacer()
                        Button { withAnimation { fullArt.toggle() } } label: {
                            DotText(text: fullArt ? "CARD" : "ART", dot: 3, color: .white.opacity(0.8)).padding(16)
                        }
                    }
                    Spacer()
                }
            }
        }
        .task(id: player.state?.item?.uri) {
            if let t = player.state?.item { await art.load(t.art); await lyrics.load(t) }
        }
    }

    private var idle: some View {
        VStack(spacing: 18) {
            DotText(text: "NOTHING PLAYING", dot: 5)
            DotText(text: "PICK A SONG IN MUSIC", dot: 2.6, color: Theme.dim)
        }
    }

    private func backdrop(_ size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [(art.colors.first ?? Color(white: 0.16)).opacity(0.9),
                                    (art.colors.dropFirst().first ?? Color(white: 0.06)).opacity(0.7), .black],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if fullArt, let img = art.image {
                Image(uiImage: img).resizable().scaledToFill().frame(width: size.width, height: size.height).clipped()
                Color.black.opacity(0.4)
            }
            Halftone(dots: art.dots, n: art.n).opacity(fullArt ? 0.5 : 0.38)
        }
        .ignoresSafeArea()
    }

    private func layout(_ size: CGSize, _ t: Track) -> some View {
        let landscape = size.width > size.height
        let side = landscape ? min(size.width * 0.3, size.height * 0.56) : min(size.width * 0.62, size.height * 0.34)
        return Group {
            if fullArt {
                VStack { Spacer(); info(t, width: min(size.width - 60, 680)).padding(.bottom, 24) }
            } else if landscape {
                HStack(spacing: 36) { artBlock(side); info(t, width: max(size.width - side - 140, 300)) }.padding(28)
            } else {
                VStack(spacing: 22) { artBlock(side); info(t, width: size.width - 60) }.padding(.top, 36)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func artBlock(_ side: CGFloat) -> some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.5), lineWidth: 2)
                    .frame(width: side + 24, height: side + 24)
                Group {
                    if let img = art.image { Image(uiImage: img).resizable().scaledToFill() } else { Theme.surface }
                }
                .frame(width: side, height: side).clipped()
            }
            .shadow(color: art.accent.opacity(0.6), radius: 30)
            .onTapGesture { withAnimation { fullArt = true } }
            VU(color: art.accent, active: player.state?.is_playing == true).frame(width: side + 24, height: 40)
        }
    }

    private func info(_ t: Track, width: CGFloat) -> some View {
        let cols = 26
        let dot = max(2.5, min(8, width / CGFloat(cols * 6)))
        return VStack(spacing: 16) {
            VStack(spacing: 8) {
                DotMarquee(text: t.name, cols: cols, dot: dot * 0.9)
                DotMarquee(text: t.artistLine, cols: cols, dot: dot * 0.55, color: .white.opacity(0.6))
            }
            lyricsView(dot: dot, cols: cols)
            progress(t, width: width)
            controls
        }
        .frame(width: width)
    }

    private func lyricsView(dot: CGFloat, cols: Int) -> some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
            let (cur, next) = lyrics.pair(atMS: player.nowMS(ctx.date))
            VStack(spacing: 10) {
                if lyrics.lines.isEmpty {
                    DotText(text: lyrics.status.isEmpty ? " " : lyrics.status, dot: dot * 0.5, color: .white.opacity(0.5))
                } else {
                    ForEach(Array(wrapDots(cur.isEmpty ? "..." : cur, cols: cols).prefix(2).enumerated()), id: \.offset) { _, l in
                        DotText(text: l, dot: dot)
                    }
                    DotText(text: String(next.dotSafe.prefix(cols)), dot: dot * 0.55, color: .white.opacity(0.42))
                }
            }
            .frame(height: dot * 18 + 24, alignment: .top)
        }
    }

    private func progress(_ t: Track, width: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let ms = player.nowMS(ctx.date), dur = max(t.duration_ms ?? 1, 1)
            VStack(spacing: 8) {
                DotBar(frac: Double(ms) / Double(dur), color: art.accent).frame(width: width, height: 14)
                HStack {
                    DotText(text: clock(ms), dot: 2.5, color: .white.opacity(0.6))
                    Spacer()
                    DotText(text: clock(dur), dot: 2.5, color: .white.opacity(0.6))
                }
                .frame(width: width)
            }
        }
    }

    private func clock(_ ms: Int) -> String { String(format: "%d:%02d", ms / 60000, (ms / 1000) % 60) }

    private var controls: some View {
        HStack(spacing: 26) {
            ctl("backward.fill") { await player.previous() }
            Button { Task { await player.toggle() } } label: {
                Image(systemName: player.state?.is_playing == true ? "pause.fill" : "play.fill")
                    .font(.system(size: 26)).foregroundColor(.black).frame(width: 64, height: 64)
                    .background(Circle().fill(Color.white))
            }
            ctl("forward.fill") { await player.next() }
            DeviceMenu(player: player)
        }
    }

    private func ctl(_ icon: String, _ action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Image(systemName: icon).font(.system(size: 22)).foregroundColor(.white).frame(width: 48, height: 48)
        }
    }
}

struct DeviceMenu: View {
    @ObservedObject var player: Player
    var body: some View {
        Menu {
            if player.devices.isEmpty { Button("No devices - open Spotify on your PC and press play") {}.disabled(true) }
            ForEach(player.devices, id: \.ident) { d in
                Button((d.is_active ? "• " : "") + d.name) { Task { await player.transfer(d) } }
            }
        } label: {
            Image(systemName: "hifispeaker.fill").font(.system(size: 20)).foregroundColor(Theme.red).frame(width: 48, height: 48)
        }
    }
}
