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
        if path.hasPrefix("/open?") {
            let query = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems
            if let id = query?.first(where: { $0.name == "id" })?.value {
                return id
            }
        }
        if path.hasPrefix("/document/d/") || path.hasPrefix("/spreadsheets/d/") || path.hasPrefix("/presentation/d/") {
            let remainder = String(path.dropFirst("/document/d/".count))
            return remainder.components(separatedBy: "/").first
        }
        if path.count >= 33 && path.count <= 50 {
            return path.lastPathComponent
        }
        return nil
    }
}
