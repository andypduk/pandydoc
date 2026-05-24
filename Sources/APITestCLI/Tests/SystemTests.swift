import Foundation

func runSystemTests(_ client: APIClient) async {
    await runTest("Get settings") {
        let (data, response) = try await client.get("/api/v1/settings")
        _ = assertStatus(response, 200, "Get settings")
        _ = assertJSON(data, "Get settings returns JSON")
    }
    
    await runTest("Update settings") {
        let body: [String: Any] = ["maxUploadSizeMB": 50]
        let (data, response) = try await client.put("/api/v1/settings", body: body)
        _ = assertStatus(response, 200, "Update settings")
        _ = assertJSON(data, "Update settings returns JSON")
    }
    
    await runTest("Vacuum") {
        let (data, response) = try await client.post("/api/v1/system/vacuum")
        _ = assertStatus(response, 200, "Vacuum database")
        _ = assertJSON(data, "Vacuum returns JSON")
    }
    
    await runTest("Integrity check") {
        let (data, response) = try await client.get("/api/v1/system/integrity")
        _ = assertStatus(response, 200, "Integrity check")
        _ = assertJSON(data, "Integrity check returns JSON")
    }
}
