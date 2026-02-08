import Foundation
import Combine

final class HikeSessionStore: ObservableObject {
    @Published private(set) var sessions: [HikeSession] = []

    private let persistence: HikePersistenceService

    init(persistence: HikePersistenceService) {
        self.persistence = persistence
        reload()
    }

    func reload() {
        sessions = persistence.loadSessions()
    }

    func add(_ session: HikeSession) {
        persistence.save(session: session)
        reload()
    }

    func rename(sessionID: UUID, newName: String) {
        persistence.rename(sessionID: sessionID, newName: newName)
        reload()
    }

    func session(for sessionID: UUID) -> HikeSession? {
        sessions.first { $0.id == sessionID }
    }

    var latest: HikeSession? {
        sessions.first
    }
}
