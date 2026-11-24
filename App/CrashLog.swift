import SwiftUI
import Darwin

/// Records how h3arth died (signal or exception, with the call stack) so the next launch can show it
/// and you can copy it to whoever is fixing it. Nothing leaves the iPad unless you copy it.
enum CrashLog {
    static let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("last-crash.txt")

    static func install() {
        NSSetUncaughtExceptionHandler { e in
            CrashLog.write("exception \(e.name.rawValue): \(e.reason ?? "")\n" + e.callStackSymbols.joined(separator: "\n"))
        }
        for s in [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGTRAP, SIGFPE] {
            signal(s) { sig in
                // shortcut: not strictly signal-safe, but this only runs while dying, to leave a note behind
                CrashLog.write("signal \(sig)\n" + Thread.callStackSymbols.joined(separator: "\n"))
                signal(sig, SIG_DFL)
                raise(sig)
            }
        }
    }

    static func write(_ s: String) {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        try? "h3arth build \(build), iPadOS \(UIDevice.current.systemVersion)\n\(s)".write(to: url, atomically: false, encoding: .utf8)
    }

    /// The last crash, read once and then forgotten.
    static func take() -> String? {
        guard let s = try? String(contentsOf: url) else { return nil }
        try? FileManager.default.removeItem(at: url)
        return s
    }
}

/// Shown on the launch after a crash.
struct CrashReport: View {
    @Environment(\.pal) private var pal
    let text: String
    var done: () -> Void
    @State private var copied = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("( ;_; ) h3arth crashed last time").font(.term(30)).foregroundColor(pal.hi)
            Text("// copy this report and paste it to claude, it says exactly what broke").font(.term(20)).foregroundColor(pal.quiet)
            ScrollView { Text(text).font(.mono(11)).foregroundColor(pal.ph).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                .frame(maxHeight: 360).padding(10).box(pal.line)
            HStack(spacing: 10) {
                TermBtn(label: copied ? "copied" : "copy report", solid: true) { UIPasteboard.general.string = text; copied = true }
                TermBtn(label: "close", action: done)
            }
        }
        .glow()
        .padding(24).frame(maxWidth: 760)
        .background(pal.bg).box(pal.ph)
        .padding(30)
    }
}
