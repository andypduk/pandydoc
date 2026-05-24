import Foundation

func runVersionTests(_ client: APIClient) async {
    await runTest("List versions") {
        let (data, response) = try await client.get("/api/v1/versions")
        _ = assertStatus(response, 200, "List versions")
        _ = assertJSON(data, "List versions returns JSON")
    }
}
