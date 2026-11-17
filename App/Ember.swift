import SwiftUI
import Security

struct EmberMsg: Identifiable, Equatable {
    let id = UUID()
    let fromEmber: Bool
    let text: String
}

/// Ember inside h3arth. She answers through emb3r on your PC (pc link) or straight from an API key,
/// reacts to new songs with emb3r's own written lines, and passes on whatever emb3r says on the PC.
@MainActor
final class Ember: ObservableObject {
    @Published var msgs: [EmberMsg] = []
    @Published var toast: EmberMsg?
    @Published var thinking = false
    @Published var source = UserDefaults.standard.string(forKey: "ember.source") ?? "api" {
        didSet { UserDefaults.standard.set(source, forKey: "ember.source") }
    }
    let pc = PCLink()

    var latest: String? { msgs.last(where: \.fromEmber)?.text }
    var hasKey: Bool { !(Keychain.get("gemini") ?? "").isEmpty }

    // emb3r's personality and song reactions (main.js DEFAULT_PERSONALITY, music.js REACTIONS)
    private static let personality = "You are Ember, a small terminal-dwelling AI companion living inside a retro music app called h3arth. Keep replies concise and warm."
    private static let reactions = [
        "Ooh, {track}. Good pick.", "{artist}! My flames approve.", "Now playing: {track}. I'm listening too.",
        "{track} - turning my fire up a notch.", "Ah, {artist}. Nice.", "New song, new mood: {track}.",
        "{track}? I'll keep the coil warm for this one.", "Okay, {artist}. Good choice.",
    ]

    func react(to t: Track) {
        let artist = t.artists?.first?.name ?? "this one"
        say(Ember.reactions.randomElement()!.replacingOccurrences(of: "{track}", with: t.name).replacingOccurrences(of: "{artist}", with: artist))
    }

    func say(_ text: String) {
        let m = EmberMsg(fromEmber: true, text: text.lowercased())
        msgs.append(m)
        toast = m
    }

    func send(_ text: String, playing: Track?) async {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        msgs.append(EmberMsg(fromEmber: false, text: q))
        thinking = true
        defer { thinking = false }
        let context = playing.map { "Now playing on Spotify: \($0.name) by \($0.artistLine)." } ?? "Nothing is playing."
        do {
            let reply = source == "pc" ? try await pc.chat(q, context: context) : try await gemini(context)
            msgs.append(EmberMsg(fromEmber: true, text: reply.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()))
        } catch {
            msgs.append(EmberMsg(fromEmber: true, text: "( ;_; ) \(error.localizedDescription)"))
        }
    }

    /// Gemini's REST API with your key, the same model emb3r uses. Sends the last few messages as history.
    private func gemini(_ context: String) async throws -> String {
        guard let key = Keychain.get("gemini"), !key.isEmpty else { throw Oops("add an api key in this tab first") }
        let history = msgs.suffix(12).map { ["role": $0.fromEmber ? "model" : "user", "parts": [["text": $0.text]]] }
        let body: [String: Any] = ["systemInstruction": ["parts": [["text": Ember.personality + " " + context]]], "contents": history]
        var r = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent")!)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue(key, forHTTPHeaderField: "x-goog-api-key")   // header, not the URL, so it never lands in logs
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: r)
        struct G: Decodable { struct C: Decodable { struct Ct: Decodable { struct P: Decodable { let text: String? }; let parts: [P]? }; let content: Ct? }; let candidates: [C]? }
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw Oops((resp as? HTTPURLResponse)?.statusCode == 400 ? "that api key didn't work" : "the api said no (\((resp as? HTTPURLResponse)?.statusCode ?? 0))")
        }
        let text = (try? JSONDecoder().decode(G.self, from: data))?.candidates?.first?.content?.parts?.compactMap(\.text).joined() ?? ""
        if text.isEmpty { throw Oops("got an empty answer") }
        return text
    }

    /// While linked to emb3r, pick up whatever Ember says on the PC so it pops up here too.
    func listen() async {
        while !Task.isCancelled {
            if source == "pc", pc.paired, let lines = try? await pc.events() { lines.forEach(say) }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
        }
    }
}

struct Oops: LocalizedError {
    let msg: String
    init(_ m: String) { msg = m }
    var errorDescription: String? { msg }
}

/// h3arth <-> emb3r over your Wi-Fi. emb3r shows a QR with its address and a pairing code.
@MainActor
final class PCLink: ObservableObject {
    @Published var host = UserDefaults.standard.string(forKey: "pc.host") ?? ""
    @Published var code = Keychain.get("pc.code") ?? ""
    private var after = 0
    private var primed = false
    var paired: Bool { !host.isEmpty && !code.isEmpty }

    /// From emb3r's QR: h3arth://link?host=192.168.1.20:47823&code=123456
    func pair(_ text: String) -> Bool {
        guard let c = URLComponents(string: text), c.scheme == "h3arth",
              let h = c.queryItems?.first(where: { $0.name == "host" })?.value,
              let k = c.queryItems?.first(where: { $0.name == "code" })?.value else { return false }
        set(host: h, code: k)
        return true
    }

    func set(host h: String, code k: String) {
        host = h.trimmingCharacters(in: .whitespaces); code = k.trimmingCharacters(in: .whitespaces)
        UserDefaults.standard.set(host, forKey: "pc.host"); Keychain.set("pc.code", code)
    }

    func chat(_ text: String, context: String) async throws -> String {
        struct R: Decodable { let reply: String }
        let d = try await call("POST", "/chat", ["text": text, "context": context])
        return try JSONDecoder().decode(R.self, from: d).reply
    }

    func events() async throws -> [String] {
        struct E: Decodable { let id: Int; let text: String }
        let list = try JSONDecoder().decode([E].self, from: try await call("GET", "/events?after=\(after)", nil))
        after = list.map(\.id).max() ?? after
        defer { primed = true }
        return primed ? list.map(\.text) : []   // first look only catches up; old lines don't all pop up at once
    }

    private func call(_ method: String, _ path: String, _ body: [String: String]?) async throws -> Data {
        guard paired, let u = URL(string: "http://\(host)\(path)") else { throw Oops("link your pc first") }
        var r = URLRequest(url: u, timeoutInterval: 60)
        r.httpMethod = method
        r.setValue(code, forHTTPHeaderField: "X-Pair-Code")
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (d, resp) = try await URLSession.shared.data(for: r)
        switch (resp as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: return d
        case 401: throw Oops("emb3r didn't accept the pairing code, scan its qr again")
        default: throw Oops("emb3r on your pc didn't answer")
        }
    }
}

/// Secrets (api key, pairing code) in the Keychain rather than plain settings.
enum Keychain {
    private static func q(_ k: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "h3arth", kSecAttrAccount as String: k]
    }
    static func get(_ k: String) -> String? {
        var query = q(k)
        query[kSecReturnData as String] = true
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    static func set(_ k: String, _ v: String) {
        SecItemDelete(q(k) as CFDictionary)
        guard !v.isEmpty else { return }
        var item = q(k)
        item[kSecValueData as String] = Data(v.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
