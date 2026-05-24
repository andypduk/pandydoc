# PandyDoc REST API Design

**Date:** 2026-05-24
**Status:** Draft

## Overview

Embed a REST API server inside the existing PandyDoc macOS application using Hummingbird (Swift async HTTP framework). The API exposes every PandyDoc feature — document management, check-in/out, versioning, folders, templates, search, and system operations — as RESTful endpoints. Includes API key authentication, auto-generated OpenAPI documentation with interactive HTML docs, and two test applications (CLI + web dashboard).

## Architecture

### Server Lifecycle

- `APIServer` class initialized in `DocManagerApp` or `AppDelegate`
- Binds to configurable port (default `8080`) on `127.0.0.1`
- Shares `DatabaseManager` and `DocumentStorage` instances with GUI — no duplicate connections
- Runs on background `Task`, uses Hummingbird async lifecycle
- Starts when app launches, stops on app termination

### Package Structure

```
Package.swift
├── DocManager (existing target, extended)
│   └── API/
│       ├── APIServer.swift          # Server lifecycle, Hummingbird app setup
│       ├── APIRoutes.swift          # Route registration
│       ├── APIMiddleware.swift      # Auth, CORS, logging, error handling
│       ├── APIError.swift           # Error types + HTTP mapping
│       ├── Controllers/
│       │   ├── DocumentController.swift
│       │   ├── CheckInOutController.swift
│       │   ├── VersionController.swift
│       │   ├── FolderController.swift
│       │   ├── TemplateController.swift
│       │   ├── SearchController.swift
│       │   ├── SystemController.swift
│       │   └── DocsController.swift
│       ├── Models/
│       │   ├── APIDocument.swift    # Request/Response DTOs
│       │   ├── APIFolder.swift
│       │   ├── APIVersion.swift
│       │   ├── APISettings.swift
│       │   └── APIPagination.swift
│       └── Docs/
│           ├── openapi.json         # OpenAPI spec template
│           └── docs.html            # Interactive HTML documentation
├── APITestCLI (new executable target)
│   └── Sources/APITestCLI/
│       ├── main.swift
│       ├── APIClient.swift
│       ├── Assertions.swift
│       └── Tests/
│           ├── HealthTests.swift
│           ├── DocumentTests.swift
│           ├── CheckInOutTests.swift
│           ├── VersionTests.swift
│           ├── FolderTests.swift
│           ├── TemplateTests.swift
│           ├── SearchTests.swift
│           └── SystemTests.swift
└── Dependencies
    └── Hummingbird (~> 2.0)
```

### Layered Architecture

```
HTTP Request
  → APIMiddleware (API key auth, CORS, logging, error handling)
    → APIRoutes (Hummingbird router)
      → APIControllers (per-resource handlers)
        → DocumentStorage / DatabaseManager / CheckInOutService (existing services)
          → SQLite + File System
```

### Controllers

| Controller | Responsibility |
|---|---|
| `DocumentController` | CRUD, move, rename, tag, flag, protect, export |
| `CheckInOutController` | Check-out, check-in, save working copy, discard, lock, unlock |
| `VersionController` | List, get, restore, export versions |
| `FolderController` | CRUD, move, rename, protect, archive, list contents |
| `TemplateController` | Add/remove templates, create from template |
| `SearchController` | Search by name, filter by tags/status, tag cloud |
| `SystemController` | Health, settings, backup, restore, vacuum, integrity |
| `DocsController` | Serves OpenAPI JSON + HTML documentation + test dashboard |

### Error Handling

All service errors mapped to `APIError` with HTTP status codes. Consistent JSON error response:

```json
{
  "error": {
    "code": "document_not_found",
    "message": "Document with ID xyz not found"
  }
}
```

| HTTP Status | Error Code | When |
|---|---|---|
| 400 | `bad_request` | Invalid input, missing required fields |
| 401 | `unauthorized` | Missing or invalid API key |
| 404 | `not_found` | Resource does not exist |
| 409 | `conflict` | Document checked out by another user, protected item |
| 422 | `validation_error` | Request body fails validation |
| 500 | `internal_error` | Unexpected server error |

## API Endpoints

All endpoints under `/api/v1`. Base URL: `http://127.0.0.1:8080/api/v1`

### Documents

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/documents` | List all (`?folderId=&status=&tags=&search=&page=&limit=`) |
| `GET` | `/documents/{id}` | Get by ID |
| `POST` | `/documents` | Import (multipart: file + optional `folderId`, `tags`, `notes`) |
| `PUT` | `/documents/{id}` | Update metadata (name, notes, tags) |
| `DELETE` | `/documents/{id}` | Delete (fails if protected) |
| `POST` | `/documents/{id}/move` | Move `{ "folderId": "uuid\|null" }` |
| `POST` | `/documents/{id}/rename` | Rename `{ "name": "string" }` |
| `POST` | `/documents/{id}/export` | Export (returns file download) |
| `POST` | `/documents/{id}/flag` | Toggle flagged |
| `POST` | `/documents/{id}/protect` | Toggle protected |
| `POST` | `/documents/{id}/tags` | Add tag `{ "tag": "string" }` |
| `DELETE` | `/documents/{id}/tags/{tag}` | Remove tag |

### Check-In / Check-Out

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/documents/{id}/checkout` | Check out (returns temp file path) |
| `POST` | `/documents/{id}/checkin` | Check in `{ "filePath", "changeNotes?" }` |
| `POST` | `/documents/{id}/save-working-copy` | Save working copy (keeps checked-out) |
| `POST` | `/documents/{id}/discard-checkout` | Discard checkout |
| `POST` | `/documents/{id}/lock` | Lock document |
| `POST` | `/documents/{id}/unlock` | Unlock document |

### Versions

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/documents/{id}/versions` | List all versions |
| `GET` | `/documents/{id}/versions/{versionNumber}` | Get version metadata |
| `POST` | `/documents/{id}/versions/{versionNumber}/restore` | Restore version |
| `GET` | `/documents/{id}/versions/{versionNumber}/export` | Export version file |

### Folders

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/folders` | List all (`?parentId=`) |
| `GET` | `/folders/{id}` | Get by ID |
| `POST` | `/folders` | Create `{ "name", "parentId?" }` |
| `PUT` | `/folders/{id}` | Update `{ "name" }` |
| `DELETE` | `/folders/{id}` | Delete recursive (fails if protected) |
| `POST` | `/folders/{id}/move` | Move `{ "parentId": "uuid?\|null" }` |
| `POST` | `/folders/{id}/protect` | Toggle protected |
| `GET` | `/folders/{id}/documents` | List documents in folder |
| `POST` | `/folders/{id}/archive` | Archive (returns zip download) |

### Templates

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/templates` | List all templates |
| `POST` | `/templates/{documentId}/add` | Add to templates |
| `DELETE` | `/templates/{documentId}` | Remove from templates |
| `POST` | `/templates/{templateId}/create` | Create from template |

### Search

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/search` | Search `{ "q": "string" }` |
| `GET` | `/tags` | Tag cloud (all tags with counts) |

### System

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check `{ "status", "version" }` |
| `GET` | `/settings` | Get settings |
| `PUT` | `/settings` | Update settings |
| `POST` | `/backup` | Create backup (returns file) |
| `POST` | `/restore` | Restore from backup (multipart: file) |
| `POST` | `/vacuum` | Vacuum database |
| `GET` | `/integrity` | Integrity check |

### Auth

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/auth/regenerate` | Rotate API key (requires current key) |

### Pagination

All list endpoints support `?page=1&limit=50` (default 50, max 200). Response envelope:

```json
{
  "data": [...],
  "pagination": { "page": 1, "limit": 50, "total": 123, "totalPages": 3 }
}
```

### Request/Response Details

**Import document** (`POST /documents`):
- Multipart form with field `file` (binary), optional form fields: `folderId` (UUID string), `tags` (comma-separated string), `notes` (string)
- Returns created document JSON on success (201)

**Export endpoints** (`POST /documents/{id}/export`, `GET /versions/{n}/export`, `POST /folders/{id}/archive`, `POST /backup`):
- Response: `Content-Disposition: attachment; filename="original_name.ext"`
- Content-Type: original MIME type for documents/versions, `application/zip` for archives, `application/sqlite` for backups
- Body: raw file bytes

**Settings** (`GET/PUT /settings`):
- Updatable fields: `autoCheckInOnAppClose` (bool), `notifyOnDocumentChange` (bool), `autoVersionOnSave` (bool), `maxVersionsToKeep` (int)
- `PUT` accepts partial updates — only provided fields are changed

**Auth regenerate** (`POST /auth/regenerate`):
- Requires current API key in `X-API-Key` header
- Returns `{ "apiKey": "new_key_string" }`
- Old key is immediately invalidated

## Authentication & Middleware

### API Key Management

- Key stored in `UserDefaults` under `apiKey`
- 32-byte random hex string, generated on first app launch if missing
- Viewable/regenerable in Settings UI (new "API" tab)
- `POST /api/v1/auth/regenerate` rotates key (requires current key)

### Middleware Pipeline (request order)

1. **RequestLogger** — logs method, path, status, duration (dev mode only)
2. **APIKeyAuth** — validates `X-API-Key` header against stored key
   - Skipped for: `GET /api/v1/health`, `GET /api/docs`, `GET /api/openapi.json`, `GET /api/test-dashboard`
   - Returns `401` on failure
3. **CORSMiddleware** — allows `*` for localhost development
4. **ErrorHandling** — catches `APIError`, maps to JSON response
5. **BodyParsing** — JSON body parser (Hummingbird built-in)

### Accepted Auth Headers

- Primary: `X-API-Key: <key>`
- Alternative: `Authorization: Bearer <key>`

### Exempt Endpoints (no API key)

- `GET /api/v1/health` — API endpoint under `/api/v1/`
- `GET /api/docs` — documentation served at `/api/` prefix (not `/api/v1/`)
- `GET /api/openapi.json` — OpenAPI spec at `/api/` prefix
- `GET /api/test-dashboard` — test dashboard at `/api/` prefix

## Documentation

### OpenAPI Spec (`GET /api/openapi.json`)

- OpenAPI 3.1 JSON served dynamically
- All endpoints, schemas, auth requirements, error formats
- Auto-generated from route definitions

### HTML Documentation (`GET /api/docs`)

- Self-contained single-page HTML (no external CDN, all inline)
- Sidebar navigation grouped by resource
- Endpoint detail with method badge, path, description, auth indicator
- Collapsible request/response JSON examples
- **Try It** panel — enter API key, fill parameters, send request from browser
- Response viewer with syntax-highlighted JSON
- Copy as cURL button
- Dark mode follows macOS system appearance
- Vanilla JS + CSS, ~50KB total

## Test Applications

### CLI Test Harness (`APITestCLI`)

**Config:** Reads `API_KEY` and `BASE_URL` from environment or `~/.pandydoc-api-config`

**Test coverage:**

| File | Tests |
|---|---|
| `HealthTests` | GET /health returns ok |
| `DocumentTests` | Create → Read → Update → Move → Rename → Tag → Flag → Protect → Export → Delete (full lifecycle) |
| `CheckInOutTests` | Checkout → Save working copy → Checkin → Discard → Lock → Unlock |
| `VersionTests` | List versions → Get version → Restore → Export |
| `FolderTests` | Create → List → Move → Rename → Protect → Archive → Delete |
| `TemplateTests` | Add to templates → Create from template → Remove |
| `SearchTests` | Search by name → Filter by tag → Tag cloud |
| `SystemTests` | Settings GET/PUT → Backup → Vacuum → Integrity |

**Output:** Color-coded pass/fail per test, summary with counts.

**Usage:**
```bash
API_KEY=abc123 swift run APITestCLI           # All tests
API_KEY=abc123 swift run APITestCLI documents # Documents only
```

### Web Test Dashboard (`GET /api/test-dashboard`)

- Single HTML page, vanilla JS + CSS, no external dependencies
- Setup panel: enter API key, validate with `/health`
- Collapsible test categories matching CLI groups
- Run buttons: "Run All", per-category runs
- Live results: spinner → ✅/❌ with response details
- Response inspector: full request/response JSON per test
- Progress bar with completion percentage
- Export results as JSON

## API Key in Settings UI

New "API" tab in SettingsView:

- Display current API key (masked, with reveal toggle)
- "Regenerate Key" button with confirmation dialog
- "Copy to Clipboard" button
- Server status indicator (running/stopped)
- Port configuration field (default 8080)
- "Start/Stop Server" toggle
