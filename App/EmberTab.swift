import SwiftUI

/// Chat with Ember, emb3r style: `you >` and `ember >` lines, a prompt at the bottom.
struct EmberTab: View {
    @Environment(\.pal) private var pal
    @ObservedObject var ember: Ember
    @ObservedObject var player: Player
    @State private var text = ""
    @State private var key = ""
    @State private var scanning = false
    @State private var host = ""
    @State private var code = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(pal.line).frame(height: 1)
            if needsSetup { setup } else { transcript }
            input
        }
        .frame(maxWidth: 900)
        .padding(.horizontal, 26).padding(.vertical, 14)
        .sheet(isPresented: $scanning) {
            QRScanner { s in scanning = false; if !ember.pc.pair(s) { ember.say("( o_o ) that qr isn't from emb3r") }; ember.objectWillChange.send() }.ignoresSafeArea()
        }
    }

    private var needsSetup: Bool { ember.source == "pc" ? !ember.pc.paired : !ember.hasKey }

    private var header: some View {
        HStack(spacing: 16) {
            EmberMark(size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("ember").font(.term(36)).foregroundColor(pal.hi)
                Text("\(emberFace(playing: player.state?.is_playing == true))  // \(ember.source == "pc" ? "via emb3r on your pc" : "via your api key")")
                    .font(.term(19)).foregroundColor(pal.quiet)
            }
            .glow()
            Spacer()
            TermBtn(label: "pc link", solid: ember.source == "pc", size: 19) { ember.source = "pc" }
            TermBtn(label: "api key", solid: ember.source == "api", size: 19) { ember.source = "api" }
        }
        .padding(.bottom, 12)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if ember.msgs.isEmpty { Text("// say hi. she can see what's playing").font(.term(20)).foregroundColor(pal.dim) }
                    ForEach(ember.msgs) { m in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(m.fromEmber ? "ember >" : "you >").font(.term(23)).foregroundColor(pal.ph).frame(width: 90, alignment: .leading)
                            Text(m.text).font(.term(23)).foregroundColor(m.fromEmber ? pal.ph : pal.hi).fixedSize(horizontal: false, vertical: true)
                        }
                        .id(m.id)
                    }
                    if ember.thinking { Text("ember > ...").font(.term(23)).foregroundColor(pal.quiet) }
                }
                .glow()
                .padding(.vertical, 16)
            }
            .onChange(of: ember.msgs.count) { _ in if let l = ember.msgs.last { withAnimation { proxy.scrollTo(l.id, anchor: .bottom) } } }
        }
    }

    @ViewBuilder private var setup: some View {
        VStack(alignment: .leading, spacing: 14) {
            if ember.source == "pc" {
                Text("// link emb3r on your pc").font(.term(24)).foregroundColor(pal.ph)
                Text("// in emb3r open settings > phone link, then scan the qr it shows. same wi-fi as this ipad.").font(.term(20)).foregroundColor(pal.quiet)
                TermBtn(label: "scan emb3r's qr", solid: true) { scanning = true }
                Text("// or type it in").font(.term(18)).foregroundColor(pal.dim).padding(.top, 8)
                HStack(spacing: 10) {
                    field("192.168.1.20:47823", $host).frame(width: 260)
                    field("code", $code).frame(width: 120)
                    TermBtn(label: "link") { ember.pc.set(host: host, code: code); ember.objectWillChange.send() }
                }
            } else {
                Text("// paste an ai api key").font(.term(24)).foregroundColor(pal.ph)
                Text("// a gemini key, the same kind emb3r uses for web answers. free at aistudio.google.com. it stays in this ipad's keychain.")
                    .font(.term(20)).foregroundColor(pal.quiet).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    SecureField("", text: $key).font(.mono(14)).foregroundColor(pal.hi)
                        .placeholder(when: key.isEmpty) { Text("api key").font(.term(21)).foregroundColor(pal.dim) }
                        .padding(.horizontal, 12).padding(.vertical, 7).box(pal.ph)
                    TermBtn(label: "save", solid: true) { Keychain.set("gemini", key); key = ""; ember.objectWillChange.send() }
                }
            }
            Spacer()
        }
        .glow()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
    }

    private var input: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let t = player.state?.item {
                Text("// ember can see what's playing: \(t.name.lowercased()), \(t.artistLine.lowercased())").font(.term(17)).foregroundColor(pal.quiet)
            }
            HStack(spacing: 10) {
                Text(">").font(.term(24)).foregroundColor(pal.ph)
                field("say something...", $text).onSubmit(send)
                TermBtn(label: "send", action: send)
            }
        }
        .glow()
    }

    private func field(_ hint: String, _ v: Binding<String>) -> some View {
        TextField("", text: v).font(.term(22)).foregroundColor(pal.hi).accentColor(pal.ph)
            .autocapitalization(.none).disableAutocorrection(true)
            .placeholder(when: v.wrappedValue.isEmpty) { Text(hint).font(.term(22)).foregroundColor(pal.dim) }
            .padding(.horizontal, 12).padding(.vertical, 7).box(pal.ph)
    }

    private func send() {
        let q = text
        text = ""
        Task { await ember.send(q, playing: player.state?.item) }
    }
}

/// Ember's line popping up over whatever page you're on.
struct EmberToast: View {
    @Environment(\.pal) private var pal
    let msg: EmberMsg
    var reply: () -> Void
    var hide: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) { EmberMark(size: 30); Text("ember >").font(.term(21)).foregroundColor(pal.ph); Spacer(); Text("now").font(.term(16)).foregroundColor(pal.quiet) }
            Text(msg.text).font(.term(22)).foregroundColor(pal.hi).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) { TermBtn(label: "reply", size: 18, action: reply); TermBtn(label: "hide", size: 18, action: hide) }
        }
        .glow()
        .padding(12).frame(width: 340, alignment: .leading)
        .background(pal.bg.opacity(0.9)).box(pal.ph)
        .shadow(color: pal.ph.opacity(0.3), radius: 14)
    }
}
