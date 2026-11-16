import UIKit

/// Checks GitHub Releases for a newer build and hands the IPA to TrollStore to install.
/// iOS can't install silently, so the user taps once and TrollStore confirms.
@MainActor
final class Updater: ObservableObject {
    static let repo = "FRENCHIIIFRIES/Trollify"
    @Published var available: URL?

    private struct Release: Decodable {
        struct Asset: Decodable { let name: String; let browser_download_url: String }
        let tag_name: String
        let assets: [Asset]
    }

    func check() async {
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let r = try? JSONDecoder().decode(Release.self, from: data),
              let latest = Int(r.tag_name.replacingOccurrences(of: "build-", with: "")),
              let current = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""),
              latest > current,
              let a = r.assets.first(where: { $0.name.hasSuffix(".ipa") }) else { return }
        available = URL(string: a.browser_download_url)
    }

    func install() {
        guard let u = available,
              let enc = u.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let link = URL(string: "apple-magnifier://install?url=\(enc)") else { return }
        UIApplication.shared.open(link)
    }
}
