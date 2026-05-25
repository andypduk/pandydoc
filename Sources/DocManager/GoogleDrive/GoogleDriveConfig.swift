import Foundation

enum GoogleDriveConfig {
    static var clientID: String? {
        UserDefaults.standard.string(forKey: "GoogleDriveClientID")
    }
    static var clientSecret: String? {
        UserDefaults.standard.string(forKey: "GoogleDriveClientSecret")
    }
    static var redirectURI: String? {
        UserDefaults.standard.string(forKey: "GoogleDriveRedirectURI")
    }
}
