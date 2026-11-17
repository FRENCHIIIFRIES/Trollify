import SwiftUI
import WebKit

/// A website shown as a tab (YouTube, Instagram, PC mirror, or a custom deck tile).
struct WebTab: Identifiable, Codable, Hashable {
    var id: String
    var code: String       // 3-letter label on the side rail
    var title: String
    var url: String
    var desktop = false    // ask for the desktop version of the site
}

extension WebTab {
    static let youtube = WebTab(id: "yt", code: "YT", title: "YOUTUBE", url: "https://www.youtube.com")
    static let instagram = WebTab(id: "ig", code: "IG", title: "INSTAGRAM", url: "https://www.instagram.com")
    // Google's browser client for Chrome Remote Desktop; may not work in iOS 15 WebKit (untested).
    static let pc = WebTab(id: "pc", code: "PC", title: "PC MIRROR", url: "https://remotedesktop.google.com/access", desktop: true)
}

/// Custom deck tiles, saved on the device.
@MainActor
final class TileStore: ObservableObject {
    @Published var custom: [WebTab] = [] { didSet { save() } }

    init() {
        if let d = UserDefaults.standard.data(forKey: "tiles"),
           let p = try? JSONDecoder().decode([WebTab].self, from: d) { custom = p }
    }

    func add(name: String, url: String) {
        var u = url.trimmingCharacters(in: .whitespaces)
        if !u.contains("://") { u = "https://" + u }
        let n = name.trimmingCharacters(in: .whitespaces)
        guard URL(string: u) != nil, !n.isEmpty else { return }
        custom.append(WebTab(id: UUID().uuidString, code: String(n.uppercased().prefix(3)), title: n.uppercased(), url: u))
    }

    func remove(_ p: WebTab) { custom.removeAll { $0.id == p.id } }

    private func save() {
        if let d = try? JSONEncoder().encode(custom) { UserDefaults.standard.set(d, forKey: "tiles") }
    }
}

/// Keeps each web view alive after first use so tabs don't reload when you switch.
@MainActor
final class WebStore: ObservableObject {
    private var views: [String: WKWebView] = [:]

    func view(for p: WebTab) -> WKWebView {
        if let v = views[p.id] { return v }
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.defaultWebpagePreferences.preferredContentMode = p.desktop ? .desktop : .recommended
        let v = WKWebView(frame: .zero, configuration: cfg)
        v.allowsBackForwardNavigationGestures = true
        v.isOpaque = false
        v.backgroundColor = .black
        v.scrollView.backgroundColor = .black
        if let u = URL(string: p.url) { v.load(URLRequest(url: u)) }
        views[p.id] = v
        return v
    }
}

struct WebRep: UIViewRepresentable {
    let store: WebStore
    let page: WebTab
    func makeUIView(context: Context) -> WKWebView { store.view(for: page) }
    func updateUIView(_ v: WKWebView, context: Context) {}
}

/// Web tab with a small dot-matrix toolbar.
struct WebPane: View {
    @Environment(\.pal) private var pal
    let store: WebStore
    let page: WebTab
    var trailing: AnyView = AnyView(EmptyView())

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("// " + page.title.lowercased()).font(.term(20)).foregroundColor(pal.quiet).glow()
                Spacer()
                trailing
                TermBtn(label: "<", size: 17) { store.view(for: page).goBack() }
                TermBtn(label: "reload", size: 17) { store.view(for: page).reload() }
                TermBtn(label: "home", size: 17) { if let u = URL(string: page.url) { store.view(for: page).load(URLRequest(url: u)) } }
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            WebRep(store: store, page: page)
        }
    }
}
