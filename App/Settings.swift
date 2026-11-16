import SwiftUI

/// Settings: visual effects (turn heavy ones off on the old iPad), lyrics, updates, account, deck.
struct SettingsView: View {
    @ObservedObject var auth: Auth
    @ObservedObject var updater: Updater
    @ObservedObject var tiles: TileStore
    @AppStorage("opt.scanlines") private var scanlines = true
    @AppStorage("opt.halftone") private var halftone = true
    @AppStorage("opt.vu") private var vu = true
    @AppStorage("opt.lyrics") private var lyrics = true
    @AppStorage("opt.reduceMotion") private var reduceMotion = false
    @AppStorage("opt.autoupdate") private var autoUpdate = true
    @AppStorage("opt.pcWidth") private var pcWidth = 0.38

    private var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                DotText(text: "SETTINGS", dot: 6)

                group("LOOK") {
                    toggle("Scanlines", "Retro CRT lines over the player", $scanlines)
                    toggle("Dot-art background", "Halftone version of the album cover", $halftone)
                    toggle("LED level meter", "Animated bars under the cover", $vu)
                    toggle("Reduce motion", "Stops tickers and meters. Smoother on the old iPad", $reduceMotion)
                }

                group("MUSIC") {
                    toggle("Show lyrics", "Synced lyrics from LRCLIB", $lyrics)
                    HStack {
                        Text("PC panel width").font(Theme.mono(14)).foregroundColor(.white)
                        Spacer()
                        Text("\(Int(pcWidth * 100))%").font(Theme.mono(13)).foregroundColor(Theme.dim)
                    }
                    Slider(value: $pcWidth, in: 0.25...0.6).accentColor(Theme.red)
                }

                group("UPDATES") {
                    toggle("Check for updates automatically", "Looks on GitHub when the app opens", $autoUpdate)
                    HStack {
                        Text("Build \(build)").font(Theme.mono(14)).foregroundColor(.white)
                        Spacer()
                        Text(updater.message).font(Theme.mono(12)).foregroundColor(Theme.dim)
                    }
                    action("CHECK NOW") { Task { await updater.check() } }
                    if updater.available != nil { action("INSTALL UPDATE", accent: true) { updater.install() } }
                }

                group("ACCOUNT") {
                    Text(auth.loggedIn ? "Spotify: connected" : "Spotify: not connected")
                        .font(Theme.mono(14)).foregroundColor(.white)
                    if auth.loggedIn { action("LOG OUT OF SPOTIFY") { auth.logout() } }
                }

                group("DECK") {
                    Text("\(tiles.custom.count) custom tile\(tiles.custom.count == 1 ? "" : "s")")
                        .font(Theme.mono(14)).foregroundColor(.white)
                    action("RESET DECK TILES") { tiles.custom = [] }
                }

                Text("Trollify build \(build)").font(Theme.mono(11)).foregroundColor(Theme.dim)
            }
            .padding(28)
        }
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DotText(text: title, dot: 3, color: Theme.red)
            VStack(alignment: .leading, spacing: 16) { content() }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        }
    }

    private func toggle(_ title: String, _ sub: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.mono(14)).foregroundColor(.white)
                Text(sub).font(Theme.mono(11)).foregroundColor(Theme.dim)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: Theme.red))
    }

    private func action(_ title: String, accent: Bool = false, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title).font(Theme.mono(13, .bold)).foregroundColor(accent ? .black : .white)
                .padding(.horizontal, 20).padding(.vertical, 11)
                .background(Capsule().fill(accent ? Color.white : Color.white.opacity(0.12)))
        }
    }
}
