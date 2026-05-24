import Foundation

struct APIClient {
    let baseURL: String
    let apiKey: String
    
    init(baseURL: String = "http://127.0.0.1:8080", apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
    
    func get(_ path: String) async throws -> (Data, HTTPURLResponse) {
        try await request(path, method: "GET")
    }
    
    func post(_ path: String, body: [String: Any]? = nil) async throws -> (Data, HTTPURLResponse) {
        try await request(path, method: "POST", body: body)
    }
    
    func put(_ path: String, body: [String: Any]? = nil) async throws -> (Data, HTTPURLResponse) {
        try await request(path, method: "PUT", body: body)
    }
    
    func delete(_ path: String) async throws -> (Data, HTTPURLResponse) {
        try await request(path, method: "DELETE")
    }
    
    private func request(_ path: String, method: String, body: [String: Any]? = nil) async throws -> (Data, HTTPURLResponse) {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            fatalError("Invalid response")
        }
        return (data, httpResponse)
    }
}
