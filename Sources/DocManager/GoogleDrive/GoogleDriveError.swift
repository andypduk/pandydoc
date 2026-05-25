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
