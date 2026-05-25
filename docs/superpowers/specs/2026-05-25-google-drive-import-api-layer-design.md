# Google Drive Import — Sub-project 1: API Layer Design

## Problem
Users cannot import documents directly from Google Drive. The current import only works with local files, requiring manual download before import.

## Solution
Build a Google Drive API layer that handles OAuth2 authentication, file browsing, file downloading with progress, and share link resolution. This layer will be consumed by future UI components.

## Architecture

### New Directory: `Sources/DocManager/GoogleDrive/`

**1. `GoogleDriveError.swift`**
Error enum covering: `authFailed`, `networkError`, `downloadFailed`, `invalidLink`, `apiError(code:message:)`. Conforms to `LocalizedError`.

**2. `GoogleDriveModels.swift`**
- `GDriveItem` — Codable: `id`, `name`, `mimeType`, `size`, `parents`, `isFolder` (derived from mimeType), `downloadURL` (optional, only for files)
- `GDriveFileList` — Codable: `items: [GDriveItem]`, `nextPageToken: String?`

**3. `GoogleDriveTokenManager.swift`**
- Keychain-backed OAuth2 token storage (access token, refresh token, expiry)
- `isAuthenticated` property checks if access token is valid
- `authenticate(clientID:redirectURI:)` — launches `ASWebAuthenticationSession` for OAuth2 consent flow
- `refreshToken(clientID:clientSecret:)` — exchanges refresh token for new access token
- `signOut()` — clears all tokens from keychain
- Token auto-refreshes on API calls when expired

**4. `GoogleDriveClient.swift`**
- Singleton `GoogleDriveClient.shared`
- Configuration: `clientID`, `clientSecret`, `redirectURI` (stored in `UserDefaults` or app settings)
- Methods:
  - `authenticate()` — delegates to `GoogleDriveTokenManager`
  - `isAuthenticated` — property
  - `signOut()` — delegates to `GoogleDriveTokenManager`
  - `listFiles(parentID: String? = nil) async throws -> GDriveFileList` — calls Drive API `files.list` with appropriate query
  - `downloadFile(fileID: String, to destination: URL, progress: @escaping (Double) -> Void) async throws` — downloads with progress reporting via `URLSession.data(for:delegate:)`
  - `resolveShareLink(url: URL) async throws -> GDriveItem` — extracts file ID from share URL, fetches metadata

### API Endpoints Used
- `GET https://www.googleapis.com/drive/v3/files` — list files
- `GET https://www.googleapis.com/drive/v3/files/{fileId}?alt=media` — download file
- `GET https://www.googleapis.com/drive/v3/files/{fileId}` — get file metadata

### OAuth2 Scopes
- `https://www.googleapis.com/auth/drive.readonly` — read-only access to Drive

### ViewModel Integration
A new `GoogleDriveViewModel` (in a later sub-project) will:
- Use `GoogleDriveClient` for auth and file operations
- Reuse existing `importProgress`, `importCurrentFile`, `importTotalFiles` from `DocumentListViewModel` for download progress
- Call `performFileImportAsync` / `performFolderImportAsync` after downloading files to temp directory

## Error Handling
- Network errors wrapped in `GoogleDriveError.networkError`
- API errors (4xx, 5xx) wrapped in `GoogleDriveError.apiError`
- Token refresh failures trigger re-authentication
- Share link parsing failures return `GoogleDriveError.invalidLink`

## Configuration
User provides Google OAuth2 client credentials via app Settings. Stored in `UserDefaults`. No credentials hardcoded.
