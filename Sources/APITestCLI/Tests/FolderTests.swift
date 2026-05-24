import Foundation

func runFolderTests(_ client: APIClient) async {
    var createdFolderId: String?
    
    await runTest("Create folder") {
        let body: [String: Any] = ["name": "Test Folder CLI", "description": "Created by CLI test harness"]
        let (data, response) = try await client.post("/api/v1/folders", body: body)
        if assertStatus(response, 201, "Create folder") {
            _ = assertJSON(data, "Create folder returns JSON")
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = json["id"] as? String {
                createdFolderId = id
            }
        }
    }
    
    await runTest("List folders") {
        let (data, response) = try await client.get("/api/v1/folders")
        _ = assertStatus(response, 200, "List folders")
        _ = assertJSON(data, "List folders returns JSON")
    }
    
    if let folderId = createdFolderId {
        await runTest("Get folder") {
            let (data, response) = try await client.get("/api/v1/folders/\(folderId)")
            _ = assertStatus(response, 200, "Get folder")
            _ = assertJSON(data, "Get folder returns JSON")
        }
        
        await runTest("Update folder") {
            let body: [String: Any] = ["name": "Test Folder CLI Updated", "description": "Updated by CLI test"]
            let (data, response) = try await client.put("/api/v1/folders/\(folderId)", body: body)
            _ = assertStatus(response, 200, "Update folder")
            _ = assertJSON(data, "Update folder returns JSON")
        }
        
        await runTest("Toggle folder protect") {
            let (data, response) = try await client.put("/api/v1/folders/\(folderId)/protect")
            _ = assertStatus(response, 200, "Toggle folder protect")
            _ = assertJSON(data, "Toggle protect returns JSON")
        }
        
        await runTest("Delete folder") {
            let (_, response) = try await client.delete("/api/v1/folders/\(folderId)")
            _ = assertStatus(response, 204, "Delete folder")
        }
    } else {
        print("  ⚠️  Skipping folder CRUD tests - no folder was created")
    }
}
