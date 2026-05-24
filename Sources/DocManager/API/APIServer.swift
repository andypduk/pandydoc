import Foundation
import Hummingbird

@MainActor
final class APIServer {
    static let shared = APIServer()

    private var serverTask: Task<Void, Error>?
    private var port: Int {
        let stored = UserDefaults.standard.integer(forKey: "apiPort")
        return stored == 0 ? 8080 : stored
    }

    var isRunning: Bool { serverTask != nil && serverTask?.isCancelled == false }

    func start() async throws {
        guard !isRunning else { return }

        let router = Router()
        router.middlewares.add(CORSMiddleware())
        router.middlewares.add(APIKeyAuthMiddleware())
        router.middlewares.add(ErrorHandlingMiddleware())

        configureRoutes(router)

        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname("127.0.0.1", port: port),
                serverName: "PandyDoc API"
            )
        )

        let task = Task {
            try await app.runService(gracefulShutdownSignals: [])
        }

        serverTask = task
        print("PandyDoc API server started on http://127.0.0.1:\(port)")
    }

    func stop() async {
        guard let task = serverTask else { return }
        task.cancel()
        _ = try? await task.value
        serverTask = nil
        print("PandyDoc API server stopped")
    }
}
