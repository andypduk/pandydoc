import Foundation

struct APISettings: Codable {
    var autoCheckInOnAppClose: Bool
    var notifyOnDocumentChange: Bool
    var autoVersionOnSave: Bool
    var maxVersionsToKeep: Int
}

struct APISettingsUpdateRequest: Codable {
    let autoCheckInOnAppClose: Bool?
    let notifyOnDocumentChange: Bool?
    let autoVersionOnSave: Bool?
    let maxVersionsToKeep: Int?
}
