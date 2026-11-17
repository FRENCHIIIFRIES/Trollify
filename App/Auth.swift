import AuthenticationServices
import CryptoKit
import UIKit

extension Data {
    var b64url: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

final class Anchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor() }
    }
}

/// Spotify login with PKCE (no client secret on device). Tokens live in UserDefaults.
@MainActor
final class Auth: ObservableObject {
    @Published var error: String?   // shown on the login screen so failures are visible
    @Published var loggedIn = Demo.on || UserDefaults.standard.string(forKey: "rt") != nil
    private let d = UserDefaults.standard
    private var session: ASWebAuthenticationSession?

    private let anchor = Anchor() // presentationContextProvider is weak, so keep it alive

    func login() {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let verifier = String((0..<64).map { _ in chars.randomElement()! })
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).b64url
        var c = URLComponents(string: "https://accounts.spotify.com/authorize")!
        c.queryItems = [
            .init(name: "client_id", value: Config.clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: Config.redirect),
            .init(name: "scope", value: Config.scopes),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge),
        ]
        let s = ASWebAuthenticationSession(url: c.url!, callbackURLScheme: Config.scheme) { [weak self] url, err in
            if let err { Task { @MainActor in self?.error = "Login window: \(err.localizedDescription)" }; return }
            guard let url else { return }
            if let e = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "error" })?.value {
                Task { @MainActor in self?.error = "Spotify returned: \(e)" }; return
            }
            guard let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "code" })?.value else {
                Task { @MainActor in self?.error = "Spotify sent no login code" }; return
            }
            Task { @MainActor in
                do { try await self?.tokenRequest(["grant_type": "authorization_code", "code": code,
                    "redirect_uri": Config.redirect, "client_id": Config.clientID, "code_verifier": verifier]) }
                catch { self?.error = "Token step: \(error)" }
            }
        }
        s.presentationContextProvider = anchor
        session = s
        s.start()
    }

    /// Login done on a PC: the QR carries a refresh token; trade it for an access token.
    func pair(_ text: String) async {
        guard text.hasPrefix("trollify://pair"),
              let rt = URLComponents(string: text)?.queryItems?.first(where: { $0.name == "rt" })?.value else {
            error = "That QR isn't from the Trollify login page."; return
        }
        d.set(rt, forKey: "rt"); d.removeObject(forKey: "at"); d.removeObject(forKey: "exp")
        do { _ = try await token(); loggedIn = true; error = nil }
        catch { self.error = "Pairing failed: \(error)"; d.removeObject(forKey: "rt"); loggedIn = false }
    }

    func logout() {
        ["at", "rt", "exp"].forEach { d.removeObject(forKey: $0) }
        loggedIn = false
    }

    func token() async throws -> String {
        if let t = d.string(forKey: "at"), Date().timeIntervalSince1970 < d.double(forKey: "exp") - 30 { return t }
        guard let r = d.string(forKey: "rt") else { throw URLError(.userAuthenticationRequired) }
        try await tokenRequest(["grant_type": "refresh_token", "refresh_token": r, "client_id": Config.clientID])
        return d.string(forKey: "at") ?? ""
    }

    private func tokenRequest(_ form: [String: String]) async throws {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = form.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")" }
            .joined(separator: "&").data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        struct R: Decodable { let access_token: String; let refresh_token: String?; let expires_in: Double }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else {
            throw NSError(domain: "Spotify", code: 0, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "bad response"])
        }
        error = nil
        d.set(r.access_token, forKey: "at")
        d.set(Date().timeIntervalSince1970 + r.expires_in, forKey: "exp")
        if let rt = r.refresh_token { d.set(rt, forKey: "rt") }
        loggedIn = true
    }
}
