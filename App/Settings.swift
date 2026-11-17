import SwiftUI

/// emb3r-style settings: tabs down the left, `[x]` rows on the right. Look holds the colour picker.
struct SettingsView: View {
    @Environment(\.pal) private var pal
    @ObservedObject var auth: Auth
    @ObservedObject var updater: Updater
    @ObservedObject var tiles: TileStore
    let albumAccent: UIColor?
    @State private var tab = "look"
    @AppStorage("opt.color") private var hex = Pal.phosphor
    @AppStorage("opt.albumColours") private var albumColours = true
    @AppStorage("opt.fullLyrics") private var fullLyrics = true
    @AppStorage("opt.scanlines") private var scanlines = true
    @AppStorage("opt.glow") private var glowOn = true
    @AppStorage("opt.reduceMotion") private var reduceMotion = false
    @AppStorage("opt.boot") private var boot = true
    @AppStorage("opt.lyrics") private var lyricsOn = true
    @AppStorage("opt.reactions") private var reactions = true
    @AppStorage("opt.autoupdate") private var autoUpdate = true
    @State private var hexField = ""

    private var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?" }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(["look", "music", "updates", "account", "deck"], id: \.self) { t in
                    Button { tab = t } label: {
                        Text(t).font(.term(23)).foregroundColor(tab == t ? pal.bg : pal.quiet)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.vertical, 5)
                            .background(tab == t ? pal.ph : Color.clear)
                    }
                }
                Spacer()
                Text("// h3arth build \(build)").font(.term(17)).foregroundColor(pal.dim).padding(18)
            }
            .glow()
            .frame(width: 200).padding(.top, 16)
            Rectangle().fill(pal.line).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(tab).font(.term(44)).foregroundColor(pal.hi).glow(true)
                    switch tab {
                    case "look": look
                    case "music":
                        TermToggle(title: "album colours", sub: "opening an album paints the screen in its cover's colours", on: $albumColours)
                        TermToggle(title: "full-screen cover lyrics", sub: "the cover fills the screen behind the words", on: $fullLyrics)
                        TermToggle(title: "show lyrics", sub: "synced lyrics from lrclib", on: $lyricsOn)
                        TermToggle(title: "ember's song reactions", sub: "a line from ember when a new song starts", on: $reactions)
                    case "updates":
                        TermToggle(title: "check automatically", sub: "looks on github when the app opens", on: $autoUpdate)
                        Text("build \(build)  // \(updater.message.lowercased())").font(.term(22)).foregroundColor(pal.ph)
                        HStack {
                            TermBtn(label: "check now") { Task { await updater.check() } }
                            if updater.available != nil { TermBtn(label: "install update", solid: true) { updater.install() } }
                        }
                    case "account":
                        Text(auth.loggedIn ? "spotify: linked" : "spotify: not linked").font(.term(24)).foregroundColor(pal.ph)
                        if auth.loggedIn { TermBtn(label: "log out of spotify") { auth.logout() } }
                    default:
                        Text("\(tiles.custom.count) custom tile\(tiles.custom.count == 1 ? "" : "s")").font(.term(24)).foregroundColor(pal.ph)
                        TermBtn(label: "reset tiles") { tiles.custom = [] }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30).padding(.vertical, 20)
            }
        }
        .onAppear { hexField = hex }
    }

    // MARK: look
    private var look: some View {
        let ui = UIColor(hex: hex) ?? UIColor(hex: Pal.phosphor)!
        let pos = ui.pickerPosition
        return VStack(alignment: .leading, spacing: 16) {
            Text("// your colour").font(.term(18)).foregroundColor(pal.dim)
            Bar(colors: stride(from: 0.0, through: 1.0, by: 1.0 / 8).map { Color(hue: $0, saturation: 0.75, brightness: 1) }, value: pos.hue) {
                set(UIColor.picked(hue: $0, light: pos.light))
            }
            Bar(colors: [Color(UIColor.picked(hue: pos.hue, light: 0)), Color(UIColor.picked(hue: pos.hue, light: 0.5)), .white], value: pos.light) {
                set(UIColor.picked(hue: pos.hue, light: $0))
            }
            HStack(spacing: 10) {
                ForEach(Pal.presets, id: \.self) { p in
                    Button { set(UIColor(hex: p)!) } label: {
                        Rectangle().fill(Color(UIColor(hex: p)!)).frame(width: 34, height: 34).padding(4)
                            .box(p == hex ? pal.ph : pal.lineStrong, p == hex ? 2 : 1)
                    }
                }
            }
            HStack(spacing: 10) {
                Text("hex").font(.term(22)).foregroundColor(pal.ph)
                TextField("", text: $hexField).font(.mono(15)).foregroundColor(pal.hi).frame(width: 120)
                    .padding(.horizontal, 10).padding(.vertical, 6).box(pal.ph)
                    .autocapitalization(.allCharacters).disableAutocorrection(true)
                    .onSubmit { if let c = UIColor(hex: hexField) { set(c) } else { hexField = hex } }
                if let a = albumAccent { TermBtn(label: "use album colour") { set(a) } }
            }
            Text("// screen").font(.term(18)).foregroundColor(pal.dim).padding(.top, 6)
            TermToggle(title: "scanlines", sub: "crt lines over everything", on: $scanlines)
            TermToggle(title: "glow", sub: "soft bloom round the text", on: $glowOn)
            TermToggle(title: "boot animation", sub: "emb3r's torches when h3arth opens", on: $boot)
            TermToggle(title: "reduce motion", sub: "smoother on the old ipad", on: $reduceMotion)
        }
    }

    private func set(_ c: UIColor) { hex = c.hex; hexField = hex }
}

/// A draggable colour bar with a knob.
private struct Bar: View {
    let colors: [Color]
    let value: Double
    let change: (Double) -> Void
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                Rectangle().stroke(Color.white, lineWidth: 2).frame(width: 8, height: 36)
                    .shadow(color: .black, radius: 2).offset(x: g.size.width * value - 4)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { change(max(0, min(1, Double($0.location.x / g.size.width)))) })
        }
        .frame(height: 28)
        .frame(maxWidth: 520)
    }
}
