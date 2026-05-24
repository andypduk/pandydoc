import Foundation

final class APIKeyManager {
    static let shared = APIKeyManager()
    
    private let defaults = UserDefaults.standard
    private let keyKey = "apiKey"
    
    var apiKey: String {
        if let existing = defaults.string(forKey: keyKey), !existing.isEmpty {
            return existing
        }
        let newKey = generateKey()
        defaults.set(newKey, forKey: keyKey)
        return newKey
    }
    
    func regenerateKey() -> String {
        let newKey = generateKey()
        defaults.set(newKey, forKey: keyKey)
        return newKey
    }
    
    func validateKey(_ key: String) -> Bool {
        key == apiKey
    }
    
    private func generateKey() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
