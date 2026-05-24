import Foundation
import Hummingbird

struct HealthResponse: Codable {
    let status: String
    let version: String
}

struct StatusResponse: Codable {
    let status: String
}

struct IntegrityResponse: Codable {
    let status: String
    let details: String
}

struct RegenerateKeyResponse: Codable {
    let apiKey: String
}

struct SystemController {
    private let dbManager = DatabaseManager.shared
    private let apiKeyManager = APIKeyManager.shared

    func registerRoutes(_ router: Router<some RequestContext>) {
        router.get("api/v1/health", use: health)
        router.get("api/v1/settings", use: getSettings)
        router.put("api/v1/settings", use: updateSettings)
        router.post("api/v1/vacuum", use: vacuum)
        router.get("api/v1/integrity", use: integrity)
        router.post("api/v1/auth/regenerate", use: regenerateKey)
    }

    func health(_ request: Request, context: some RequestContext) async throws -> Response {
        return try encodeJSON(HealthResponse(status: "ok", version: "1.0"), context: context)
    }

    func getSettings(_ request: Request, context: some RequestContext) async throws -> Response {
        let settings = APISettings(
            autoCheckInOnAppClose: UserDefaults.standard.bool(forKey: "autoCheckInOnAppClose"),
            notifyOnDocumentChange: UserDefaults.standard.bool(forKey: "notifyOnDocumentChange"),
            autoVersionOnSave: UserDefaults.standard.bool(forKey: "autoVersionOnSave"),
            maxVersionsToKeep: UserDefaults.standard.integer(forKey: "maxVersionsToKeep")
        )
        return try encodeJSON(settings, context: context)
    }

    func updateSettings(_ request: Request, context: some RequestContext) async throws -> Response {
        let body = try await request.decode(as: APISettingsUpdateRequest.self, context: context)
        if let val = body.autoCheckInOnAppClose { UserDefaults.standard.set(val, forKey: "autoCheckInOnAppClose") }
        if let val = body.notifyOnDocumentChange { UserDefaults.standard.set(val, forKey: "notifyOnDocumentChange") }
        if let val = body.autoVersionOnSave { UserDefaults.standard.set(val, forKey: "autoVersionOnSave") }
        if let val = body.maxVersionsToKeep { UserDefaults.standard.set(val, forKey: "maxVersionsToKeep") }
        return try await getSettings(request, context: context)
    }

    func vacuum(_ request: Request, context: some RequestContext) async throws -> Response {
        try dbManager.vacuum()
        return try encodeJSON(StatusResponse(status: "ok"), context: context)
    }

    func integrity(_ request: Request, context: some RequestContext) async throws -> Response {
        let result = try dbManager.integrityCheck()
        let status = result == "ok" ? "ok" : "failed"
        let details = result == "ok" ? "Database integrity verified" : result
        return try encodeJSON(IntegrityResponse(status: status, details: details), context: context)
    }

    func regenerateKey(_ request: Request, context: some RequestContext) async throws -> Response {
        let newKey = apiKeyManager.regenerateKey()
        return try encodeJSON(RegenerateKeyResponse(apiKey: newKey), context: context)
    }
}
