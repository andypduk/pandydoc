import Foundation
import Hummingbird

private struct APICheckoutResponse: Codable {
    let document: APIDocument
    let tempFilePath: String
}

struct CheckInOutController {
    private let checkInOut = CheckInOutService.shared
    private let storage = DocumentStorage.shared
    
    func registerRoutes(_ router: Router<some RequestContext>) {
        router.post("api/v1/documents/:id/checkout", use: checkOut)
        router.post("api/v1/documents/:id/checkin", use: checkIn)
        router.post("api/v1/documents/:id/save-working-copy", use: saveWorkingCopy)
        router.post("api/v1/documents/:id/discard-checkout", use: discardCheckout)
        router.post("api/v1/documents/:id/lock", use: lock)
        router.post("api/v1/documents/:id/unlock", use: unlock)
    }
    
    func checkOut(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        let response = try checkInOut.checkOut(documentId: id)
        guard response.success, let doc = response.document else {
            throw APIError.conflict(response.error ?? "Checkout failed")
        }
        let apiResponse = APICheckoutResponse(
            document: APIDocument(from: doc),
            tempFilePath: response.tempFilePath ?? ""
        )
        return try encodeJSON(apiResponse, context: context)
    }
    
    func checkIn(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        let body = try await request.decode(as: APICheckInRequest.self, context: context)
        let doc = try checkInOut.checkIn(documentId: id, changeNotes: body.changeNotes)
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
    
    func saveWorkingCopy(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        let doc = try checkInOut.saveWorkingCopy(documentId: id)
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
    
    func discardCheckout(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        try checkInOut.discardCheckOut(documentId: id)
        return Response(status: .noContent)
    }
    
    func lock(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        try checkInOut.lock(documentId: id)
        guard let doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
    
    func unlock(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let id = context.parameters.get("id", as: UUID.self) else {
            throw APIError.badRequest("Invalid document ID")
        }
        try checkInOut.unlock(documentId: id)
        guard let doc = storage.getDocument(id: id) else {
            throw APIError.notFound("Document not found")
        }
        return try encodeJSON(APIDocument(from: doc), context: context)
    }
}
