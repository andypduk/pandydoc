import Foundation

let apiKey = ProcessInfo.processInfo.environment["API_KEY"] ?? {
    print("Error: API_KEY environment variable required")
    exit(1)
}()

let baseURL = ProcessInfo.processInfo.environment["BASE_URL"] ?? "http://127.0.0.1:8080"
let filterArg = CommandLine.arguments.dropFirst().first

let client = APIClient(baseURL: baseURL, apiKey: apiKey)

var passed = 0
var failed = 0

@MainActor
func runTest(_ name: String, _ test: () async throws -> Void) async {
    do {
        try await test()
        passed += 1
    } catch {
        print("  ❌ \(name): \(error.localizedDescription)")
        failed += 1
    }
}

@MainActor
func runAll() async {
    print("=== PandyDoc API Tests ===")
    print("Base URL: \(baseURL)")
    print("")
    
    if filterArg == nil || filterArg == "health" {
        print("--- Health ---")
        await runTest("Health check") {
            let (_, response) = try await client.get("/api/v1/health")
            _ = assertStatus(response, 200, "Health check")
        }
    }
    
    if filterArg == nil || filterArg == "documents" {
        print("\n--- Documents ---")
        await runDocumentTests(client)
    }
    
    if filterArg == nil || filterArg == "folders" {
        print("\n--- Folders ---")
        await runFolderTests(client)
    }
    
    if filterArg == nil || filterArg == "versions" {
        print("\n--- Versions ---")
        await runVersionTests(client)
    }
    
    if filterArg == nil || filterArg == "checkout" {
        print("\n--- Check-In/Out ---")
        await runCheckInOutTests(client)
    }
    
    if filterArg == nil || filterArg == "search" {
        print("\n--- Search ---")
        await runSearchTests(client)
    }
    
    if filterArg == nil || filterArg == "system" {
        print("\n--- System ---")
        await runSystemTests(client)
    }
    
    print("\n─────────────────────────────────")
    print("Results: \(passed) passed, \(failed) failed, \(passed + failed) total")
    exit(failed > 0 ? 1 : 0)
}

await runAll()
