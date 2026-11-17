import SwiftUI

/// emb3r's boot sequence for h3arth: dark letters, the 3 catches and throws sparks,
/// torches light left to right with the spirit travelling over them, then it fades into the app.
struct BootView: View {
    var done: () -> Void
    @AppStorage("opt.reduceMotion") private var reduce = false
    @State private var start = Date()
    private let amber = Color(red: 1, green: 0.69, blue: 0.13)
    private var length: Double { reduce ? 0.6 : 2.2 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduce)) { ctx in
            let p = Demo.screen == "boot" ? 0.62 : min(1, ctx.date.timeIntervalSince(start) / length)
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 34) {
                    Wordmark(size: 17, boot: true, lit: p > 0.12)
                        .overlay(alignment: .topLeading) { if p > 0.12 && !reduce { sparks(ctx.date) } }
                    torches(p)
                    VStack(spacing: 10) {
                        Text(status(p)).font(.term(26)).foregroundColor(amber).shadow(color: .orange.opacity(0.5), radius: 5)
                        Text("starting up").font(.term(19)).foregroundColor(Color(red: 0.43, green: 0.35, blue: 0.28))
                    }
                }
            }
        }
        .onAppear {
            start = Date()
            if Demo.screen != "boot" { DispatchQueue.main.asyncAfter(deadline: .now() + length + 0.25) { done() } }
        }
    }

    private func status(_ p: Double) -> String {
        p < 0.3 ? "striking the flint" : p < 0.6 ? "warming the valves" : p < 0.95 ? "dropping the needle" : "ready"
    }

    /// Embers rising off the 3 (the second letter: 8 Menlo cells in, 4 wide).
    private func sparks(_ date: Date) -> some View {
        let t = date.timeIntervalSinceReferenceDate
        let x0 = 12 * 17 * 0.602
        return ZStack(alignment: .topLeading) {
            ForEach(0..<8, id: \.self) { i in
                let phase = (t * 0.55 + Double(i) / 8).truncatingRemainder(dividingBy: 1)
                Rectangle().fill(amber).frame(width: 3, height: 3)
                    .shadow(color: .orange, radius: 3)
                    .opacity(1 - phase)
                    .offset(x: x0 + sin(Double(i) * 1.7 + t) * 10 - 10, y: -phase * 64)
            }
        }
    }

    /// Six torches and a brazier; the spirit sits over the one being lit.
    private func torches(_ p: Double) -> some View {
        let lit = Int(p * 7)
        return HStack(spacing: 22) {
            ForEach(0..<7, id: \.self) { i in
                let on = i < lit || p >= 1
                VStack(spacing: 2) {
                    Text("✺").font(.mono(15)).foregroundColor(Color(red: 1, green: 0.85, blue: 0.39))
                        .shadow(color: .orange, radius: 6).opacity(i == lit && p < 1 ? 1 : 0)
                    Text(i == 6 ? "◈" : "▲").font(.mono(13)).foregroundColor(on ? amber : Color(white: 0.23))
                        .shadow(color: on ? .orange.opacity(0.6) : .clear, radius: 6)
                    Text(i == 6 ? "╨" : "┃").font(.mono(11)).foregroundColor(Color(white: 0.23))
                }
            }
        }
    }
}
