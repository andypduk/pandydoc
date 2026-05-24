import Foundation

func runDocumentTests(_ client: APIClient) async {
    await runTest("List documents") {
        let (data, response) = try await client.get("/api/v1/documents")
        _ = assertStatus(response, 200, "List documents")
        _ = assertJSON(data, "List documents returns JSON")
    }
    
    await runTest("Search documents") {
        let (data, response) = try await client.get("/api/v1/documents/search?q=test")
        _ = assertStatus(response, 200, "Search documents")
        _ = assertJSON(data, "Search documents returns JSON")
    }
    
    await runTest("Auth error - missing key") {
        let url = URL(string: "\(client.baseURL)/api/v1/documents")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            fatalError("Invalid response")
        }
        _ = assertStatus(httpResponse, 401, "Missing API key returns 401")
        _ = assertJSON(data, "Auth error returns JSON")
    }
}
