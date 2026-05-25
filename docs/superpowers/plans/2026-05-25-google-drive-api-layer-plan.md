# Google Drive Import — API Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Google Drive API layer with OAuth2 authentication, file listing, file download with progress, and share link resolution.

**Architecture:** Four new Swift files under `Sources/DocManager/GoogleDrive/` — error types, models, token manager, and API client. No UI changes in this sub-project.

**Tech Stack:** Swift, SwiftUI, AuthenticationServices (ASWebAuthenticationSession), Security framework (Keychain), URLSession

---

## File Structure

**Create:**
- `Sources/DocManager/GoogleDrive/GoogleDriveError.swift` — error enum
- `Sources/DocManager/GoogleDrive/GoogleDriveModels.swift` — GDriveItem, GDriveFileList
- `Sources/DocManager/GoogleDrive/GoogleDriveTokenManager.swift` — OAuth2 token management
- `Sources/DocManager/GoogleDrive/GoogleDriveClient.swift` — API client

---

### Task 1: Create GoogleDriveError.swift

**Files:**
- Create: `Sources/DocManager/GoogleDrive/GoogleDriveError.swift`

- [ ] **Step 1: Write the error enum**

```swift
import Foundation

enum GoogleDriveError: Error, LocalizedError {
    case authFailed(String)
    case networkError(Error)
    case downloadFailed(String)
    case invalidLink(String)
    case apiError(code: Int, message: String)
    case tokenRefreshFailed
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .authFailed(let msg):
            return "Authentication failed: \(msg)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .downloadFailed(let msg):
            return "Download failed: \(msg)"
        case .invalidLink(let msg):
            return "Invalid Google Drive link: \(msg)"
        case .apiError(_, let message):
            return "Google Drive API error: \(message)"
        case .tokenRefreshFailed:
            return "Failed to refresh authentication token"
        case .notAuthenticated:
            return "Not authenticated with Google Drive"
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/GoogleDrive/GoogleDriveError.swift
git commit -m "feat: add GoogleDriveError enum"
```

---

### Task 2: Create GoogleDriveModels.swift

**Files:**
- Create: `Sources/DocManager/GoogleDrive/GoogleDriveModels.swift`

- [ ] **Step 1: Write the models**

```swift
import Foundation

struct GDriveItem: Codable, Identifiable {
    let id: String
    let name: String
    let mimeType: String
    let size: Int64?
    let parents: [String]?
    let downloadURL: String?

    var isFolder: Bool {
        mimeType == "application/vnd.google-apps.folder"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, mimeType, size, parents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        mimeType = try container.decode(String.self, forKey: .mimeType)
        size = try container.decodeIfPresent(Int64.self, forKey: .size)
        parents = try container.decodeIfPresent([String].self, forKey: .parents)
        downloadURL = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(parents, forKey: .parents)
    }
}

struct GDriveFileList: Codable {
    let items: [GDriveItem]
    let nextPageToken: String?

    enum CodingKeys: String, CodingKey {
        case items = "files"
        case nextPageToken
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/GoogleDrive/GoogleDriveModels.swift
git commit -m "feat: add Google Drive API models"
```

---

### Task 3: Create GoogleDriveTokenManager.swift

**Files:**
- Create: `Sources/DocManager/GoogleDrive/GoogleDriveTokenManager.swift`

- [ ] **Step 1: Write the token manager**

```swift
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
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: URL(string: redirectURI)!.scheme!) { callbackURL, error in
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
```

- [ ] **Step 2: Commit**

```bash
git add Sources/DocManager/GoogleDrive/GoogleDriveTokenManager.swift
git commit -m "feat: add Google Drive OAuth2 token manager"
```

---

### Task 4: Create GoogleDriveClient.swift

**Files:**
- Create: `Sources/DocManager/GoogleDrive/GoogleDriveClient.swift`

- [ ] **Step 1: Write the API client**

```swift
import Foundation

@MainActor
final class GoogleDriveClient: ObservableObject {
    static let shared = GoogleDriveClient()

    private let tokenManager = GoogleDriveTokenManager.shared
    private let baseURL = "https://www.googleapis.com/drive/v3"

    var isAuthenticated: Bool {
        tokenManager.isAuthenticated
    }

    func authenticate() async throws {
        guard let clientID = GoogleDriveConfig.clientID,
              let redirectURI = GoogleDriveConfig.redirectURI else {
            throw GoogleDriveError.authFailed("Google Drive not configured. Set client ID in Settings.")
        }
        try await tokenManager.authenticate(clientID: clientID, redirectURI: redirectURI)
    }

    func signOut() {
        tokenManager.signOut()
    }

    func listFiles(parentID: String? = nil) async throws -> GDriveFileList {
        let token = try await tokenManager.getValidAccessToken(
            clientID: GoogleDriveConfig.clientID ?? "",
            clientSecret: GoogleDriveConfig.clientSecret ?? ""
        )

        var query = "trashed = false"
        if let parentID = parentID {
            query += " and '\(parentID)' in parents"
        } else {
            query += " and 'root' in parents"
        }

        var components = URLComponents(string: "\(baseURL)/files")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fields", value: "files(id,name,mimeType,size,parents),nextPageToken"),
            URLQueryItem(name: "pageSize", value: "1000")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleDriveError.networkError(NSError(domain: "GoogleDrive", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response"]))
        }
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GoogleDriveError.apiError(code: httpResponse.statusCode, message: message)
        }

        return try JSONDecoder().decode(GDriveFileList.self, from: data)
    }

    func downloadFile(fileID: String, to destination: URL, progress: @escaping (Double) -> Void) async throws {
        let token = try await tokenManager.getValidAccessToken(
            clientID: GoogleDriveConfig.clientID ?? "",
            clientSecret: GoogleDriveConfig.clientSecret ?? ""
        )

        let url = URL(string: "\(baseURL)/files/\(fileID)?alt=media")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleDriveError.downloadFailed("No response")
        }
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GoogleDriveError.apiError(code: httpResponse.statusCode, message: message)
        }

        try data.write(to: destination)
        progress(1.0)
    }

    func resolveShareLink(url: URL) async throws -> GDriveItem {
        guard let fileID = extractFileID(from: url) else {
            throw GoogleDriveError.invalidLink("Could not extract file ID from URL")
        }

        let token = try await tokenManager.getValidAccessToken(
            clientID: GoogleDriveConfig.clientID ?? "",
            clientSecret: GoogleDriveConfig.clientSecret ?? ""
        )

        let apiURL = URL(string: "\(baseURL)/files/\(fileID)")!
        var components = URLComponents(url: apiURL, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "fields", value: "id,name,mimeType,size,parents")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleDriveError.networkError(NSError(domain: "GoogleDrive", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response"]))
        }
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GoogleDriveError.apiError(code: httpResponse.statusCode, message: message)
        }

        return try JSONDecoder().decode(GDriveItem.self, from: data)
    }

    private func extractFileID(from url: URL) -> String? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let id = components.queryItems?.first(where: { $0.name == "id" })?.value {
            return id
        }
        let path = url.path
        if path.hasPrefix("/file/d/") {
            let remainder = String(path.dropFirst("/file/d/".count))
            return remainder.components(separatedBy: "/").first
        }
        if path.hasPrefix("/open?") || path.hasPrefix("/document/d/") || path.hasPrefix("/spreadsheets/d/") {
            let query = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems
            if let id = query?.first(where: { $0.name == "id" })?.value {
                return id
            }
            let remainder = String(path.dropFirst("/document/d/".count))
            return remainder.components(separatedBy: "/").first
        }
        if path.count == 33 || path.count == 44 {
            return path.lastPathComponent
        }
        return nil
    }
}
```

- [ ] **Step 2: Create GoogleDriveConfig.swift**

Create `Sources/DocManager/GoogleDrive/GoogleDriveConfig.swift`:

```swift
import Foundation

enum GoogleDriveConfig {
    static var clientID: String? {
        UserDefaults.standard.string(forKey: "GoogleDriveClientID")
    }
    static var clientSecret: String? {
        UserDefaults.standard.string(forKey: "GoogleDriveClientSecret")
    }
    static var redirectURI: String? {
        UserDefaults.standard.string(forKey: "GoogleDriveRedirectURI")
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Sources/DocManager/GoogleDrive/GoogleDriveClient.swift Sources/DocManager/GoogleDrive/GoogleDriveConfig.swift
git commit -m "feat: add Google Drive API client and config"
```

---

### Task 5: Verify Build

- [ ] **Step 1: Build the project**

Run: `swift build`
Expected: Build succeeds with no errors

- [ ] **Step 2: Commit if build passes**

```bash
git add -A
git commit -m "chore: verify Google Drive API layer builds cleanly"
```
