import AVFoundation

@_silgen_name("trollify_start") private func trollify_start(_ name: UnsafePointer<CChar>, _ cache: UnsafePointer<CChar>) -> Int32
@_silgen_name("trollify_status") private func trollify_status(_ buf: UnsafeMutablePointer<CChar>, _ len: Int) -> Int

/// On-device Spotify Connect player (librespot, Rust). Shows up as "Trollify iPad" in Spotify's device list.
@MainActor
final class Engine: ObservableObject {
    @Published var status = "OFF"
    private var polling = false

    var running: Bool { status != "OFF" && !status.hasPrefix("ERROR") && status != "STOPPED" }

    func start() {
        guard !running else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("librespot").path
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let r = "Trollify iPad".withCString { n in dir.withCString { c in trollify_start(n, c) } }
        status = r == 0 ? "STARTING" : "ERROR COULD NOT START"
        poll()
    }

    private func poll() {
        guard !polling else { return }
        polling = true
        Task {
            while !Task.isCancelled {
                var buf = [CChar](repeating: 0, count: 256)
                _ = trollify_status(&buf, buf.count)
                let s = String(cString: buf)
                if !s.isEmpty && s != status { status = s }
                if s == "READY" { UserDefaults.standard.set(true, forKey: "engine.ok") }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}
