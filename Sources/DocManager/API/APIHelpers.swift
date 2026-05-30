import Foundation
import Hummingbird

enum InputValidation {
    static let maxNameLength = 255
    static let maxTagLength = 100
    static let maxNotesLength = 10_000
    static let maxTagCount = 50

    static func validateName(_ name: String, field: String = "name") throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.validationError("\(field) must not be empty")
        }
        guard name.count <= maxNameLength else {
            throw APIError.validationError("\(field) must not exceed \(maxNameLength) characters")
        }
        let controlChars = CharacterSet.controlCharacters.subtracting(.newlines)
        guard name.unicodeScalars.allSatisfy({ !controlChars.contains($0) }) else {
            throw APIError.validationError("\(field) contains invalid control characters")
        }
    }

    static func validateTag(_ tag: String) throws {
        guard !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.validationError("Tag must not be empty")
        }
        guard tag.count <= maxTagLength else {
            throw APIError.validationError("Tag must not exceed \(maxTagLength) characters")
        }
    }

    static func validateTags(_ tags: [String]) throws {
        guard tags.count <= maxTagCount else {
            throw APIError.validationError("Too many tags (max \(maxTagCount))")
        }
        for tag in tags {
            try validateTag(tag)
        }
    }

    static func validateNotes(_ notes: String) throws {
        guard notes.count <= maxNotesLength else {
            throw APIError.validationError("Notes must not exceed \(maxNotesLength) characters")
        }
    }
}

func encodeJSON<T: Codable>(_ value: T, context: some RequestContext) throws -> Response {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(value)
    let body = String(data: data, encoding: .utf8) ?? ""
    return Response(
        status: .ok,
        headers: [.contentType: "application/json"],
        body: .init(byteBuffer: ByteBuffer(string: body))
    )
}
