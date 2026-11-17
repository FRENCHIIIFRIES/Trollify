import SwiftUI

/// Home, laid out like emb3r's hero: the mark and the name, the face, then what's playing,
/// the app tiles, what's up next, and a prompt at the bottom.
struct HomeView: View {
    @Environment(\.pal) private var pal
    @ObservedObject var player: Player
    @ObservedObject var art: ArtModel
    @ObservedObject var tiles: TileStore
    @ObservedObject var ember: Ember
    var go: (String) -> Void
    @State private var query = ""
    @State private var adding = false

    var body: some View {
        GeometryReader { g in
            let narrow = g.size.width < 900
            VStack(spacing: narrow ? 14 : 18) {
                hero(narrow)
                nowPlaying
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: narrow ? 3 : 5), spacing: 12) {
                    tile(1, "music", glyph: "♫  ♪\n ♪ ♫") { go("music") }
                    tile(2, "player", glyph: "[▮▮▮▯▯]\n lyrics") { go("player") }
                    tile(3, "youtube", glyph: "┌────┐\n│ ▶  │\n└────┘") { go(WebTab.youtube.id) }
                    Button { go("ember") } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            EmberMark(size: 36)
                            Spacer(minLength: 8)
                            Text("ember").font(.term(28)).foregroundColor(pal.ph).lineLimit(1).glow()
                        }
                        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .overlay(alignment: .topTrailing) { Text("4").font(.mono(11)).foregroundColor(pal.dim).padding(9) }
                        .box(pal.lineStrong)
                    }
                    ForEach(Array(tiles.custom.enumerated()), id: \.element.id) { i, t in
                        tile(5 + i, t.title.lowercased(), glyph: "┌──┐\n│◉ │\n└──┘") { go(t.id) }
                            .contextMenu { Button("Remove tile") { tiles.remove(t) } }
                    }
                    Button { adding = true } label: {
                        Text("[ + add tile ]").font(.term(21)).foregroundColor(pal.dim)
                            .frame(maxWidth: .infinity, minHeight: 104)
                            .overlay(Rectangle().stroke(pal.dim, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                    }
                }
                upNext
                Spacer(minLength: 0)
                prompt
            }
            .padding(.horizontal, narrow ? 22 : 34).padding(.top, 20).padding(.bottom, 18)
        }
        .sheet(isPresented: $adding) { AddTile(tiles: tiles) }
    }

    private func hero(_ narrow: Bool) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 20) {
                EmberMark(size: narrow ? 78 : 100)
                Wordmark(size: narrow ? 11 : 14)
            }
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(emberFace(playing: player.state?.is_playing == true)).font(.term(30)).foregroundColor(pal.ph)
                Text("mood " + String(repeating: "#", count: player.state?.is_playing == true ? 5 : 2)).font(.term(17)).foregroundColor(pal.quiet)
            }
            .glow()
            if let l = ember.latest {
                (Text("ember > ").foregroundColor(pal.ph) + Text(l).foregroundColor(pal.hi) + Text(" █").foregroundColor(pal.ph))
                    .font(.term(22)).lineLimit(1).glow()
            }
        }
    }

    @ViewBuilder private var nowPlaying: some View {
        if let t = player.state?.item {
            HStack(spacing: 18) {
                DitherArt(dots: art.dots, n: art.n, size: 78)
                VStack(alignment: .leading, spacing: 4) {
                    (Text(t.name.lowercased()).font(.term(27)) + Text("  // \(t.artistLine.lowercased())").font(.term(20)).foregroundColor(pal.quiet))
                        .lineLimit(1)
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let ms = player.nowMS(ctx.date), dur = max(t.duration_ms ?? 1, 1)
                        Text("\(clock(ms)) \(asciiBar(Double(ms) / Double(dur), 30)) \(clock(dur))").font(.mono(13)).foregroundColor(pal.quiet)
                    }
                }
                .foregroundColor(pal.ph).glow()
                Spacer(minLength: 0)
                TermBtn(label: "|<") { Task { await player.previous() } }
                TermBtn(label: player.state?.is_playing == true ? "pause" : "play", solid: true) { Task { await player.toggle() } }
                TermBtn(label: ">|") { Task { await player.next() } }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .box(pal.lineStrong)
            .contentShape(Rectangle())
            .onTapGesture { go("player") }
        } else {
            Text("// nothing playing. open music, or start spotify on any device")
                .font(.term(20)).foregroundColor(pal.quiet).frame(maxWidth: .infinity, minHeight: 70).box(pal.line)
        }
    }

    private func tile(_ k: Int, _ name: String, glyph: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(glyph).font(.mono(13)).foregroundColor(pal.quiet).fixedSize()
                Spacer(minLength: 8)
                Text(name).font(.term(28)).foregroundColor(pal.ph).lineLimit(1)
            }
            .glow()
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .overlay(alignment: .topTrailing) { Text("\(k)").font(.mono(11)).foregroundColor(pal.dim).padding(9) }
            .box(pal.lineStrong)
        }
    }

    @ViewBuilder private var upNext: some View {
        if !player.queue.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("// up next").font(.term(18)).foregroundColor(pal.quiet).padding(.bottom, 4)
                ForEach(Array(player.queue.prefix(2).enumerated()), id: \.offset) { i, t in
                    HStack {
                        Text(String(format: "%02d", i + 2)).font(.mono(12)).foregroundColor(pal.dim).frame(width: 34, alignment: .leading)
                        Text(t.name.lowercased()).font(.term(21)).foregroundColor(pal.ph).lineLimit(1)
                        Spacer()
                        Text(t.artistLine.lowercased()).font(.term(21)).foregroundColor(pal.quiet).lineLimit(1).frame(width: 260, alignment: .leading)
                        Text(clock(t.duration_ms ?? 0)).font(.mono(12)).foregroundColor(pal.dim).frame(width: 52, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                    .overlay(alignment: .bottom) { Rectangle().fill(pal.line).frame(height: 1) }
                }
            }
            .glow()
        }
    }

    private var prompt: some View {
        VStack(spacing: 8) {
            Text("// type a song to play it, or start with @ember to talk to her").font(.term(19)).foregroundColor(pal.quiet).glow()
            HStack(spacing: 10) {
                Text(">").font(.term(24)).foregroundColor(pal.ph)
                TextField("", text: $query)
                    .font(.term(22)).foregroundColor(pal.hi).accentColor(pal.ph)
                    .placeholder(when: query.isEmpty) { Text("search spotify, or @ember ...").font(.term(22)).foregroundColor(pal.dim) }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .box(pal.ph)
                    .onSubmit(send)
                TermBtn(label: "play", action: send)
            }
            .glow()
        }
    }

    private func send() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        query = ""
        if q.lowercased().hasPrefix("@ember") {
            go("ember")
            Task { await ember.send(String(q.dropFirst(6)), playing: player.state?.item) }
            return
        }
        go("music")
        Task { await player.search(q); if let t = player.tracks.first { await player.play(t) } }
        query = ""
    }
}

extension View {
    /// A placeholder we can colour (TextField's own is always system grey).
    func placeholder<P: View>(when show: Bool, @ViewBuilder _ p: () -> P) -> some View {
        ZStack(alignment: .leading) { if show { p().allowsHitTesting(false) }; self }
    }
}

struct AddTile: View {
    @ObservedObject var tiles: TileStore
    @Environment(\.presentationMode) private var presentation
    @State private var name = ""
    @State private var url = ""

    var body: some View {
        NavigationView {
            Form {
                TextField("Name (e.g. Twitch)", text: $name)
                TextField("Website (e.g. twitch.tv)", text: $url)
                    .autocapitalization(.none).disableAutocorrection(true)
            }
            .navigationTitle("New tile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { tiles.add(name: name, url: url); presentation.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { presentation.wrappedValue.dismiss() } }
            }
        }
    }
}
