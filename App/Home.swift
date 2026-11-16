import SwiftUI

/// Dot-matrix home screen: big clock, now playing, status, and a deck of launcher tiles.
struct HomeView: View {
    @ObservedObject var player: Player
    @ObservedObject var tiles: TileStore
    var go: (String) -> Void
    @State private var adding = false
    @State private var battery = 0

    private static let time: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
    private static let day: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE d MMM"; return f }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    VStack(alignment: .leading, spacing: 12) {
                        DotText(text: Self.time.string(from: ctx.date), dot: 11, color: .white, off: Color.white.opacity(0.07))
                        DotText(text: Self.day.string(from: ctx.date), dot: 4, color: Theme.red)
                    }
                }
                HStack(alignment: .top, spacing: 18) { nowCard; statusCard }
                DotText(text: "DECK", dot: 3, color: Theme.dim)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 14)], spacing: 14) {
                    tile("MUSIC", "SPOTIFY", "music")
                    tile("NOW", "PLAYER + LYRICS", "now")
                    tile(WebTab.youtube.title, "VIDEOS", WebTab.youtube.id)
                    tile(WebTab.instagram.title, "FEED", WebTab.instagram.id)
                    ForEach(tiles.custom) { p in
                        tile(p.title, URL(string: p.url)?.host ?? "", p.id)
                            .contextMenu { Button("Remove tile") { tiles.remove(p) } }
                    }
                    Button { adding = true } label: {
                        DotText(text: "+ ADD", dot: 3, color: Theme.red)
                            .frame(maxWidth: .infinity, minHeight: 92).padding(16)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.red.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2, 4])))
                    }
                }
            }
            .padding(28)
        }
        .sheet(isPresented: $adding) { AddTile(tiles: tiles) }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            battery = max(Int(UIDevice.current.batteryLevel * 100), 0)
        }
    }

    private var nowCard: some View {
        Button { go("now") } label: {
            HStack(spacing: 14) {
                Art(url: player.state?.item?.art, size: 84)
                VStack(alignment: .leading, spacing: 10) {
                    if let t = player.state?.item {
                        DotMarquee(text: t.name, cols: 16, dot: 3.4)
                        DotText(text: String(t.artistLine.dotSafe.prefix(24)), dot: 2.2, color: Theme.dim)
                    } else {
                        DotText(text: "NOTHING PLAYING", dot: 3)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DotText(text: "BAT \(battery)%", dot: 3.4)
            DotText(text: String("OUT \(player.state?.device?.name ?? "NO DEVICE")".dotSafe.prefix(20)), dot: 2.6, color: Theme.dim)
        }
        .padding(16).frame(width: 280, alignment: .leading).frame(minHeight: 116)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
    }

    private func tile(_ title: String, _ sub: String, _ id: String) -> some View {
        Button { go(id) } label: {
            VStack(alignment: .leading, spacing: 14) {
                DotText(text: String(title.dotSafe.prefix(10)), dot: 2.8)
                DotText(text: String(sub.dotSafe.prefix(14)), dot: 2, color: Theme.dim)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading).padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [2, 4])))
        }
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
            .navigationTitle("New deck tile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { tiles.add(name: name, url: url); presentation.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { presentation.wrappedValue.dismiss() } }
            }
        }
    }
}
