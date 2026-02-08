import Foundation
import SwiftData

struct SwiftDataHikePersistenceService: HikePersistenceService {
    private struct StoredPayload: Codable {
        let id: UUID
        let startedAt: Date
        let endedAt: Date
        let route: [LocationPoint]
        let segments: [TrailSegment]
        let finalFatigue: FatigueState
        let finalSafety: SafetyState
    }

    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(context: ModelContext) {
        self.context = context
    }

    func loadSessions() -> [HikeSession] {
        let descriptor = FetchDescriptor<PersistedHikeRecord>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor).compactMap { record in
                guard let payload = try? decoder.decode(StoredPayload.self, from: record.payload) else {
                    return nil
                }

                return HikeSession(
                    id: payload.id,
                    name: record.name,
                    startedAt: payload.startedAt,
                    endedAt: payload.endedAt,
                    route: payload.route,
                    segments: payload.segments,
                    finalFatigue: payload.finalFatigue,
                    finalSafety: payload.finalSafety
                )
            }
        } catch {
            return []
        }
    }

    func save(session: HikeSession) {
        let payload = StoredPayload(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            route: session.route,
            segments: session.segments,
            finalFatigue: session.finalFatigue,
            finalSafety: session.finalSafety
        )

        guard let data = try? encoder.encode(payload) else { return }

        let record = PersistedHikeRecord(
            id: session.id,
            name: session.displayName,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            payload: data
        )

        context.insert(record)
        try? context.save()
    }

    func rename(sessionID: UUID, newName: String) {
        let cleaned = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        var descriptor = FetchDescriptor<PersistedHikeRecord>(
            predicate: #Predicate { $0.id == sessionID }
        )
        descriptor.fetchLimit = 1

        guard let record = try? context.fetch(descriptor).first else { return }
        record.name = cleaned
        try? context.save()
    }
}
