import Foundation
import SwiftData

@Model
final class PersistedHikeRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var startedAt: Date
    var endedAt: Date
    var payload: Data
    var createdAt: Date

    init(id: UUID, name: String, startedAt: Date, endedAt: Date, payload: Data, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.payload = payload
        self.createdAt = createdAt
    }
}
