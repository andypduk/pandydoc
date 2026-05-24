import Foundation

func runSearchTests(_ client: APIClient) async {
    await runTest("Search by query") {
        let (data, response) = try await client.get("/api/v1/search?q=test")
        _ = assertStatus(response, 200, "Search by query")
        _ = assertJSON(data, "Search returns JSON")
    }
    
    await runTest("Get tag cloud") {
        let (data, response) = try await client.get("/api/v1/tags/cloud")
        _ = assertStatus(response, 200, "Get tag cloud")
        _ = assertJSON(data, "Tag cloud returns JSON")
    }
}
