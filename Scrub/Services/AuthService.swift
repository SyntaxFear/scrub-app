import Foundation
import AuthenticationServices
import CryptoKit
import AppKit

/// The signed-in person, as returned by the backend (no secrets).
struct AuthUser: Codable, Equatable, Sendable {
    let id: String
    let email: String
    let name: String?
    let image: String?
}

enum AuthError: Error {
    case network
    case server(String)
    var message: String {
        switch self {
        case .network: return "Network error — check your connection and try again."
        case .server(let m): return m
        }
    }
}

/// Native Google OAuth client config. Filled in once the client is created in the
/// Google Cloud Console (see docs/AUTH-SETUP.md). Empty values disable Google
/// sign-in gracefully.
enum GoogleConfig {
    // iOS-type OAuth client (PKCE, no secret). The redirect scheme is the reversed
    // client ID, which ASWebAuthenticationSession intercepts directly.
    static let clientID = "911024272540-tjm706j444c0mh4ejj4fbit5m7cs59pu.apps.googleusercontent.com"
    static let clientSecret = ""  // iOS client has no secret — PKCE only
    static let scheme = "com.googleusercontent.apps.911024272540-tjm706j444c0mh4ejj4fbit5m7cs59pu"
    static var redirectURI: String { "\(scheme):/oauth2redirect" }
    static var isConfigured: Bool { !clientID.isEmpty }
}

/// Sign in with Apple for the Developer ID build uses Apple's web OAuth Services
/// ID, because native Apple Sign In requires a Developer ID provisioning profile.
enum AppleConfig {
    static let serviceID = "app.scrubmac.web"
    static let scheme = "com.levani.scrub.auth"
    static let redirectURI = "https://scrubmac.app/api/auth/callback/apple"
    static var isConfigured: Bool { !serviceID.isEmpty }
}

/// Drives the required sign-in wall and talks to the Convex native-auth endpoints.
/// All token/code verification happens server-side; the app only ever holds an
/// opaque session token (in the Keychain).
@MainActor
@Observable
final class AuthStore: NSObject {
    enum State: Equatable {
        case unknown          // checking a stored session
        case signedOut
        case signedIn(AuthUser)
    }

    var state: State = .unknown
    var errorMessage: String?
    var isBusy = false

    var googleAvailable: Bool { GoogleConfig.isConfigured }

    private let base = URL(string: "https://healthy-shepherd-34.eu-west-1.convex.site/native/auth")!
    private var webSession: ASWebAuthenticationSession?

    // MARK: - Session lifecycle

    /// On launch, validate any stored token.
    func restore() async {
        guard let token = Keychain.token() else { state = .signedOut; return }
        do {
            let data = try await post("session", ["token": token])
            let resp = try JSONDecoder().decode(SessionResponse.self, from: data)
            state = .signedIn(resp.user)
        } catch {
            Keychain.clear()
            state = .signedOut
        }
    }

    func signOut() {
        if let token = Keychain.token() {
            Task { _ = try? await post("signout", ["token": token]) }
        }
        Keychain.clear()
        state = .signedOut
    }

    // MARK: - Sign in with Apple

    func signInWithApple() {
        errorMessage = nil
        guard AppleConfig.isConfigured else {
            errorMessage = "Apple sign-in isn’t set up yet."
            return
        }

        let state = Self.randomURLSafe(32)
        var comps = URLComponents(string: "https://appleid.apple.com/auth/authorize")!
        comps.queryItems = [
            .init(name: "client_id", value: AppleConfig.serviceID),
            .init(name: "redirect_uri", value: AppleConfig.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "response_mode", value: "query"),
            .init(name: "scope", value: "name email"),
            .init(name: "state", value: state),
        ]

        let session = ASWebAuthenticationSession(
            url: comps.url!, callbackURLScheme: AppleConfig.scheme
        ) { [weak self] callback, error in
            guard let self else { return }
            if let error = error as? NSError {
                if error.code != ASAuthorizationError.canceled.rawValue {
                    Task { @MainActor in self.errorMessage = self.appleSignInMessage(for: error) }
                }
                return
            }

            guard let callback,
                  let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems else {
                Task { @MainActor in self.errorMessage = "Apple sign-in did not return a callback." }
                return
            }
            if let appleError = items.first(where: { $0.name == "error" })?.value {
                Task { @MainActor in self.errorMessage = "Apple sign-in failed: \(appleError)." }
                return
            }
            guard items.first(where: { $0.name == "state" })?.value == state,
                  let code = items.first(where: { $0.name == "code" })?.value,
                  !code.isEmpty else {
                Task { @MainActor in self.errorMessage = "Apple sign-in returned an invalid response." }
                return
            }
            Task { await self.exchangeApple(code: code) }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        webSession = session
        session.start()
    }

    // MARK: - Sign in with Google (PKCE)

    func signInWithGoogle() {
        errorMessage = nil
        guard GoogleConfig.isConfigured else {
            errorMessage = "Google sign-in isn’t set up yet."
            return
        }
        let verifier = Self.randomURLSafe(64)
        let challenge = Self.codeChallenge(for: verifier)
        let state = Self.randomURLSafe(32)
        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id", value: GoogleConfig.clientID),
            .init(name: "redirect_uri", value: GoogleConfig.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
        ]
        let session = ASWebAuthenticationSession(
            url: comps.url!, callbackURLScheme: GoogleConfig.scheme
        ) { [weak self] callback, _ in
            guard let self,
                  let callback,
                  let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems,
                  items.first(where: { $0.name == "state" })?.value == state,
                  let code = items.first(where: { $0.name == "code" })?.value else { return }
            Task { await self.exchangeGoogle(code: code, verifier: verifier) }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        webSession = session
        session.start()
    }

    private func exchangeGoogle(code: String, verifier: String) async {
        isBusy = true
        defer { isBusy = false }
        do {
            var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
            req.httpMethod = "POST"
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var params = [
                "client_id": GoogleConfig.clientID,
                "code": code,
                "code_verifier": verifier,
                "grant_type": "authorization_code",
                "redirect_uri": GoogleConfig.redirectURI,
            ]
            if !GoogleConfig.clientSecret.isEmpty {
                params["client_secret"] = GoogleConfig.clientSecret
            }
            let form = params
                .map { "\($0.key)=\(Self.formEncode($0.value))" }
                .joined(separator: "&")
            req.httpBody = form.data(using: .utf8)

            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let idToken = json["id_token"] as? String else {
                throw AuthError.server("Google sign-in failed.")
            }
            let result = try await post("google", ["idToken": idToken])
            try handleAuth(result)
        } catch {
            errorMessage = (error as? AuthError)?.message ?? "Google sign-in failed."
        }
    }

    private func exchangeApple(code: String) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await post("apple-code", ["code": code])
            try handleAuth(result)
        } catch {
            errorMessage = (error as? AuthError)?.message ?? "Apple sign-in failed."
        }
    }

    // MARK: - Email code

    /// Requests a code; returns true if it was sent.
    func requestEmailCode(_ email: String) async -> Bool {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await post("email/request", ["email": email])
            return true
        } catch {
            errorMessage = (error as? AuthError)?.message ?? "Couldn’t send the code."
            return false
        }
    }

    func verifyEmailCode(email: String, code: String) async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            let data = try await post("email/verify", ["email": email, "code": code])
            try handleAuth(data)
        } catch {
            errorMessage = (error as? AuthError)?.message ?? "Incorrect code."
        }
    }

    // MARK: - Networking

    private struct AuthResponse: Codable { let token: String; let user: AuthUser }
    private struct SessionResponse: Codable { let user: AuthUser }
    private struct ErrorResponse: Codable { let error: String }

    private func post(_ path: String, _ body: [String: Any]) async throws -> Data {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthError.network }
        if http.statusCode >= 400 {
            let msg = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
                ?? "Sign-in failed."
            throw AuthError.server(msg)
        }
        return data
    }

    private func handleAuth(_ data: Data) throws {
        let resp = try JSONDecoder().decode(AuthResponse.self, from: data)
        Keychain.saveToken(resp.token)
        state = .signedIn(resp.user)
    }

    // MARK: - PKCE / encoding helpers

    private static func randomURLSafe(_ count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func codeChallenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formEncode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }
}

// MARK: - Presentation anchors

extension AuthStore: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = cred.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            errorMessage = "Apple sign-in failed."
            return
        }
        let name = [cred.fullName?.givenName, cred.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let data = try await post("apple", ["identityToken": idToken, "name": name])
                try handleAuth(data)
            } catch {
                errorMessage = (error as? AuthError)?.message ?? "Apple sign-in failed."
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        // Cancellation is silent; other failures surface a message.
        let nsError = error as NSError
        if nsError.code != ASAuthorizationError.canceled.rawValue {
            errorMessage = appleSignInMessage(for: nsError)
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor()
    }
}

extension AuthStore: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor()
    }
}

private extension AuthStore {
    func anchor() -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first ?? NSWindow()
    }

    func appleSignInMessage(for error: NSError) -> String {
        let details = error.localizedDescription
        let suffix = details.isEmpty ? "" : " \(details)"
        switch ASAuthorizationError.Code(rawValue: error.code) {
        case .failed:
            return "Apple sign-in failed. Make sure Scrub was installed from the latest signed DMG and try again.\(suffix)"
        case .invalidResponse:
            return "Apple sign-in returned an invalid response. Please try again.\(suffix)"
        case .notHandled:
            return "Apple sign-in could not be handled on this Mac. Check that you are signed into your Apple Account in System Settings.\(suffix)"
        case .notInteractive:
            return "Apple sign-in needs an interactive window. Bring Scrub to the front and try again.\(suffix)"
        case .unknown:
            return "Apple sign-in failed because macOS returned an unknown authorization error.\(suffix)"
        default:
            return "Apple sign-in failed.\(suffix)"
        }
    }
}
