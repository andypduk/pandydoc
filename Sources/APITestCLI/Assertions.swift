import Foundation

func assertStatus(_ response: HTTPURLResponse, _ expected: Int, _ message: String) -> Bool {
    if response.statusCode != expected {
        print("  ❌ \(message): expected status \(expected), got \(response.statusCode)")
        return false
    }
    print("  ✅ \(message)")
    return true
}

func assertJSON(_ data: Data, _ message: String) -> Bool {
    do {
        _ = try JSONSerialization.jsonObject(with: data)
        print("  ✅ \(message)")
        return true
    } catch {
        print("  ❌ \(message): invalid JSON")
        return false
    }
}

func printJSON(_ data: Data) {
    if let json = try? JSONSerialization.jsonObject(with: data),
       let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
       let string = String(data: pretty, encoding: .utf8) {
        print(string)
    } else if let string = String(data: data, encoding: .utf8) {
        print(string)
    }
}
