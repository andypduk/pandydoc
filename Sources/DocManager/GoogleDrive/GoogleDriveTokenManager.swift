import Foundation
import Security
import AuthenticationServices

@MainActor
final class GoogleDriveTokenManager: ObservableObject {
    static let shared = GoogleDriveTokenManager()

    @Published private(set) var isAuthenticated = false

    private let service = "com.pandydoc.googledrive"
    private let accessTokenAccount = "accessToken"
    private let refreshTokenAccount = "refreshToken"
    private let expiryAccount = "tokenExpiry"

    private var accessToken: String? {
        get { readKeychain(account: accessTokenAccount) }
        set { writeKeychain(account: accessTokenAccount, value: newValue) }
    }

    private var refreshToken: String? {
        get { readKeychain(account: refreshTokenAccount) }
        set { writeKeychain(account: refreshTokenAccount, value: newValue) }
    }

    private var tokenExpiry: Date? {
        get {
            guard let data = readKeychainData(account: expiryAccount),
                  let date = try? JSONDecoder().decode(Date.self, from: data) else { return nil }
            return date
        }
        set {
            if let value = newValue, let data = try? JSONEncoder().encode(value) {
                writeKeychainData(account: expiryAccount, data: data)
            } else {
                deleteKeychain(account: expiryAccount)
            }
        }
    }

    init() {
        checkAuthStatus()
    }

    func authenticate(clientID: String, redirectURI: String) async throws {
        let authURL = buildAuthURL(clientID: clientID, redirectURI: redirectURI)
        let callbackURL = try await presentAuthSession(url: authURL, redirectURI: redirectURI)
        guard let code = extractAuthCode(from: callbackURL) else {
            throw GoogleDriveError.authFailed("No authorization code received")
        }
        try await exchangeCodeForTokens(code: code, clientID: clientID, redirectURI: redirectURI)
    }

    func getValidAccessToken(clientID: String, clientSecret: String) async throws -> String {
        if let token = accessToken, let expiry = tokenExpiry, expiry > Date() {
            return token
        }
        guard let refresh = refreshToken else {
            throw GoogleDriveError.notAuthenticated
        }
        try await refreshAccessToken(refreshToken: refresh, clientID: clientID, clientSecret: clientSecret)
        guard let newToken = accessToken else {
            throw GoogleDriveError.tokenRefreshFailed
        }
        return newToken
    }

    func signOut() {
        deleteKeychain(account: accessTokenAccount)
        deleteKeychain(account: refreshTokenAccount)
        deleteKeychain(account: expiryAccount)
        isAuthenticated = false
    }

    private func checkAuthStatus() {
        isAuthenticated = accessToken != nil && tokenExpiry.map { $0 > Date() } ?? false
    }

    private func buildAuthURL(clientID: String, redirectURI: String) -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/drive.readonly"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url!
    }

    private func presentAuthSession(url: URL, redirectURI: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let redirectComponents = URLComponents(string: redirectURI)
            let scheme = redirectComponents?.scheme ?? ""
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: GoogleDriveError.authFailed(error.localizedDescription))
                    return
                }
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: GoogleDriveError.authFailed("No callback URL received"))
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = ASWebAuthPresentationProvider.shared
            session.start()
        }
    }

    private func extractAuthCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return nil
        }
        return code
    }

    private func exchangeCodeForTokens(code: String, clientID: String, redirectURI: String) async throws {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleDriveError.authFailed("Token exchange failed")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let accessToken = json?["access_token"] as? String,
           let expiresIn = json?["expires_in"] as? Int,
           let refreshToken = json?["refresh_token"] as? String {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
            isAuthenticated = true
        } else {
            throw GoogleDriveError.authFailed("Invalid token response")
        }
    }

    private func refreshAccessToken(refreshToken: String, clientID: String, clientSecret: String) async throws {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "refresh_token": refreshToken,
            "client_id": clientID,
            "client_secret": clientSecret,
            "grant_type": "refresh_token"
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleDriveError.tokenRefreshFailed
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let accessToken = json?["access_token"] as? String,
           let expiresIn = json?["expires_in"] as? Int {
            self.accessToken = accessToken
            self.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
            isAuthenticated = true
        } else {
            throw GoogleDriveError.tokenRefreshFailed
        }
    }

    private func readKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return (result as? Data).flatMap { String(data: $0, encoding: .utf8) }
    }

    private func readKeychainData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    private func writeKeychain(account: String, value: String?) {
        deleteKeychain(account: account)
        guard let value = value else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: value.data(using: .utf8)!
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func writeKeychainData(account: String, data: Data) {
        deleteKeychain(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private final class ASWebAuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = ASWebAuthPresentationProvider()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}
