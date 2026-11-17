import SwiftUI

/// The player. Lyrics view: the cover fills the screen and the sung words light up.
/// Cover view: framed cover, transcript-style lyrics, controls.
struct PlayerScreen: View {
    @Environment(\.pal) private var pal
    @ObservedObject var player: Player
    @ObservedObject var lyrics: Lyrics
    @ObservedObject var art: ArtModel
    @AppStorage("opt.fullLyrics") private var fullLyrics = true

    var body: some View {
        GeometryReader { g in
            if let t = player.state?.item {
                if fullLyrics && Demo.screen != "card" { full(t, g.size) } else { card(t, g.size) }
            } else {
                Text("// nothing playing. pick a song in music").font(.term(24)).foregroundColor(pal.quiet)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: lyrics view
    private func full(_ t: Track, _ size: CGSize) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let img = art.image {
                Image(uiImage: img).resizable().scaledToFill().frame(width: size.width, height: size.height).clipped().blur(radius: 1.5)
            }
            LinearGradient(stops: [.init(color: .black.opacity(0.5), location: 0), .init(color: .black.opacity(0.15), location: 0.28),
                                   .init(color: pal.bg.opacity(0.75), location: 0.62), .init(color: .black.opacity(0.94), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 22) {
                Spacer()
                karaoke(big: size.width > 900 ? 60 : 52)
                strip(t)
            }
            .padding(.horizontal, size.width > 900 ? 44 : 28).padding(.bottom, 20)
            TermBtn(label: "cover view", size: 18) { fullLyrics = false }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(16)
        }
        .clipped()
    }

    private func karaoke(big: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
            let k = lyrics.karaoke(atMS: player.nowMS(ctx.date))
            VStack(alignment: .leading, spacing: 8) {
                if lyrics.lines.isEmpty {
                    Text("// " + (lyrics.status.isEmpty ? "no lyrics" : lyrics.status.lowercased())).font(.term(30)).foregroundColor(pal.quiet)
                } else {
                    Text(k.prev.lowercased()).font(.term(28)).foregroundColor(pal.hi.opacity(0.35))
                    sung(k.cur.lowercased(), k.frac).font(.term(big)).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                    ForEach(Array(k.next.enumerated()), id: \.offset) { i, l in
                        Text(l.lowercased()).font(.term(30)).foregroundColor(pal.hi.opacity(i == 0 ? 0.6 : 0.3))
                    }
                }
            }
            .frame(maxWidth: 880, alignment: .leading)
            .shadow(color: pal.ph.opacity(0.6), radius: 4)
        }
    }

    /// Words already sung lit, the rest waiting.
    private func sung(_ line: String, _ frac: Double) -> Text {
        let words = line.split(separator: " ").map(String.init)
        let n = Int((frac * Double(words.count)).rounded(.up))
        return Text(words.prefix(n).joined(separator: " ") + (n < words.count && n > 0 ? " " : "")).foregroundColor(pal.hi)
            + Text(words.dropFirst(n).joined(separator: " ")).foregroundColor(pal.hi.opacity(0.4))
    }

    private func strip(_ t: Track) -> some View {
        HStack(spacing: 16) {
            Art(url: t.art(min: 100), size: 56)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(t.name.lowercased())  // \(t.artistLine.lowercased())").font(.term(24)).foregroundColor(pal.ph).lineLimit(1)
                progress(t)
            }
            controls(size: 20)
        }
        .padding(12).background(Color.black.opacity(0.5)).box(pal.lineStrong)
    }

    private func progress(_ t: Track) -> some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let ms = player.nowMS(ctx.date), dur = max(t.duration_ms ?? 1, 1)
            VStack(spacing: 4) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(pal.hi.opacity(0.15))
                        Rectangle().fill(LinearGradient(colors: pal.fill, startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * min(1, CGFloat(ms) / CGFloat(dur))).shadow(color: pal.ph, radius: 5)
                    }
                }
                .frame(height: 5)
                HStack { Text(clock(ms)); Spacer(); Text(clock(dur)) }.font(.mono(11)).foregroundColor(pal.quiet)
            }
        }
    }

    private func controls(size: CGFloat) -> some View {
        HStack(spacing: 8) {
            TermBtn(label: "|<", size: size) { Task { await player.previous() } }
            TermBtn(label: player.state?.is_playing == true ? "pause" : "play", solid: true, size: size) { Task { await player.toggle() } }
            TermBtn(label: ">|", size: size) { Task { await player.next() } }
        }
    }

    // MARK: cover view
    private func card(_ t: Track, _ size: CGSize) -> some View {
        let land = size.width > size.height
        let side = land ? min(size.width * 0.33, size.height * 0.62) : min(size.width * 0.58, size.height * 0.4)
        let cover = VStack(spacing: 14) {
            Art(url: t.art, size: side).padding(8).box(pal.ph).shadow(color: pal.ph.opacity(0.35), radius: 18)
            Text("\(emberFace(playing: player.state?.is_playing == true))  playing on \(player.state?.device?.name.lowercased() ?? "nothing")")
                .font(.term(21)).foregroundColor(pal.quiet).lineLimit(1)
            DeviceMenu(player: player)
        }
        let info = VStack(alignment: land ? .leading : .center, spacing: 8) {
            Text(t.name.lowercased()).font(.term(60)).foregroundColor(pal.hi).lineLimit(1).minimumScaleFactor(0.5).glow(true)
            Text("\(t.artistLine.lowercased())").font(.term(24)).foregroundColor(pal.quiet).lineLimit(1)
            transcript.padding(.vertical, 14)
            progress(t)
            controls(size: 22).padding(.top, 6)
        }
        return Group {
            if land { HStack(alignment: .top, spacing: 36) { cover; info.frame(maxWidth: .infinity) } }
            else { VStack(spacing: 18) { cover; info } }
        }
        .padding(28)
        .overlay(alignment: .topTrailing) { TermBtn(label: "lyrics view", size: 18) { fullLyrics = true }.padding(16) }
    }

    private var transcript: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let k = lyrics.karaoke(atMS: player.nowMS(ctx.date))
            VStack(alignment: .leading, spacing: 6) {
                Text("// lyrics").font(.term(17)).foregroundColor(pal.dim)
                if !k.prev.isEmpty { Text("  " + k.prev.lowercased()).font(.term(24)).foregroundColor(pal.dim) }
                (Text("> ").foregroundColor(pal.ph) + sung(k.cur.lowercased(), k.frac)).font(.term(32)).glow(true)
                ForEach(Array(k.next.enumerated()), id: \.offset) { _, l in Text("  " + l.lowercased()).font(.term(24)).foregroundColor(pal.quiet) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// `[ device ]` picker for where Spotify plays.
struct DeviceMenu: View {
    @Environment(\.pal) private var pal
    @ObservedObject var player: Player
    var body: some View {
        Menu {
            if player.devices.isEmpty { Button("No devices - open Spotify somewhere and press play") {}.disabled(true) }
            ForEach(player.devices, id: \.ident) { d in
                Button((d.is_active ? "• " : "") + d.name) { Task { await player.transfer(d) } }
            }
        } label: {
            Text("[ device ]").font(.term(19)).foregroundColor(pal.ph).padding(.horizontal, 10).padding(.vertical, 3).box(pal.ph).glow()
        }
    }
}
