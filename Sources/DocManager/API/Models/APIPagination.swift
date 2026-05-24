import Foundation

struct APIPagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

struct PaginatedResponse<T: Codable>: Codable {
    let data: [T]
    let pagination: APIPagination
}
