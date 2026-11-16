import SwiftUI

/// Home: greeting + dot-matrix clock, now-playing card, and a grid of app tiles.
struct HomeView: View {
    @ObservedObject var player: Player
    @ObservedObject var tiles: TileStore
    var go: (String) -> Void
    @State private var adding = false
    @State private var battery = 0

    private static let time: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
    private static let day: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEEE, d MMMM"; return f }()

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                hero
                pills
                Text("Apps").font(Theme.mono(22, .bold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], spacing: 16) {
                    appTile("Music", "Your Spotify library", "music.note", [.green, .mint], "music")
                    appTile("Player", "Cover, lyrics, controls", "waveform", [.purple, .indigo], "now")
                    appTile("YouTube", "Videos", "play.fill", [.red, .orange], WebTab.youtube.id)
                    appTile("Instagram", "Feed and reels", "camera.fill", [.pink, .orange], WebTab.instagram.id)
                    ForEach(tiles.custom) { p in
                        appTile(p.title.capitalized, URL(string: p.url)?.host ?? "", "globe", [.blue, .cyan], p.id)
                            .contextMenu { Button("Remove tile") { tiles.remove(p) } }
                    }
                    Button { adding = true } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "plus").font(.system(size: 22, weight: .semibold))
                            Text("Add tile").font(Theme.mono(14, .semibold))
                        }
                        .foregroundColor(Theme.dim).frame(maxWidth: .infinity, minHeight: 112)
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6])))
                    }
                }
            }
            .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 30)
        }
        .sheet(isPresented: $adding) { AddTile(tiles: tiles) }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            battery = max(Int(UIDevice.current.batteryLevel * 100), 0)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting).font(.system(size: 38, weight: .bold, design: .rounded))
                Text(Self.day.string(from: Date())).font(Theme.mono(16)).foregroundColor(Theme.dim)
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                DotText(text: Self.time.string(from: ctx.date), dot: 6.5, color: .white, off: Color.white.opacity(0.08))
            }
        }
    }

    private var hero: some View {
        let t = player.state?.item
        return HStack(spacing: 22) {
            Art(url: t?.art(min: 300), size: 124, radius: 18)
            VStack(alignment: .leading, spacing: 8) {
                Text(t == nil ? "NOT PLAYING" : "NOW PLAYING").font(Theme.mono(11, .bold)).tracking(1.6).foregroundColor(Theme.red)
                Text(t?.name ?? "Pick something in Music").font(.system(size: 26, weight: .bold, design: .rounded)).lineLimit(2)
                Text(t?.artistLine ?? "or start Spotify on a device").font(Theme.mono(15)).foregroundColor(Theme.dim).lineLimit(1)
                if t != nil {
                    HStack(spacing: 14) {
                        Button { Task { await player.toggle() } } label: {
                            Image(systemName: player.state?.is_playing == true ? "pause.fill" : "play.fill")
                                .font(.system(size: 18)).foregroundColor(.black).frame(width: 46, height: 46).background(Circle().fill(Color.white))
                        }
                        Button { Task { await player.next() } } label: {
                            Image(systemName: "forward.fill").font(.system(size: 18)).foregroundColor(.white).frame(width: 46, height: 46)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(LinearGradient(colors: [Color.white.opacity(0.13), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .contentShape(Rectangle())
        .onTapGesture { go("now") }
    }

    private var pills: some View {
        HStack(spacing: 12) {
            pill("hifispeaker.fill", player.state?.device?.name ?? "No device")
            pill("battery.100", "\(battery)%")
        }
    }

    private func pill(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(Theme.red)
            Text(text).font(Theme.mono(13, .semibold)).lineLimit(1)
        }
        .padding(.horizontal, 14).padding(.vertical, 9).background(Capsule().fill(Theme.card))
    }

    private func appTile(_ title: String, _ sub: String, _ icon: String, _ colors: [Color], _ id: String) -> some View {
        Button { go(id) } label: {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Theme.mono(17, .semibold)).foregroundColor(.white)
                    Text(sub).font(Theme.mono(12)).foregroundColor(Theme.dim).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
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
