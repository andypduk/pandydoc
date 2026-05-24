import Foundation
import Hummingbird

struct TagInfo: Codable {
    let tag: String
    let count: Int
}

struct SearchResponse: Codable {
    let data: [APIDocument]
}

struct TagCloudResponse: Codable {
    let data: [TagInfo]
}

struct SearchController {
    private let storage = DocumentStorage.shared

    func registerRoutes(_ router: Router<some RequestContext>) {
        router.get("api/v1/search", use: search)
        router.get("api/v1/tags", use: tagCloud)
    }

    func search(_ request: Request, context: some RequestContext) async throws -> Response {
        let query = request.uri.queryParameters["q"].map { String($0) } ?? ""
        let docs = storage.searchDocuments(query: query, tags: [])
        let response = SearchResponse(data: docs.map { APIDocument(from: $0) })
        return try encodeJSON(response, context: context)
    }

    func tagCloud(_ request: Request, context: some RequestContext) async throws -> Response {
        let tags = storage.getAllTags()
        let tagData = tags.map { TagInfo(tag: $0.tag, count: $0.count) }
        let response = TagCloudResponse(data: tagData)
        return try encodeJSON(response, context: context)
    }
}
