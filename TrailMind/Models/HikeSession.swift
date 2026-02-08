import Foundation

struct HikeSession: Identifiable, Codable {
    let id: UUID
    var name: String
    let startedAt: Date
    let endedAt: Date
    let route: [LocationPoint]
    let segments: [TrailSegment]
    let finalFatigue: FatigueState
    let finalSafety: SafetyState

    init(
        id: UUID = UUID(),
        name: String? = nil,
        startedAt: Date,
        endedAt: Date,
        route: [LocationPoint],
        segments: [TrailSegment],
        finalFatigue: FatigueState,
        finalSafety: SafetyState
    ) {
        self.id = id
        if let cleanedName = name?.trimmingCharacters(in: .whitespacesAndNewlines), !cleanedName.isEmpty {
            self.name = cleanedName
        } else {
            self.name = HikeSession.defaultName(from: startedAt)
        }
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.route = route
        self.segments = segments
        self.finalFatigue = finalFatigue
        self.finalSafety = finalSafety
    }

    var totalDistance: Double {
        segments.reduce(0) { $0 + $1.distance }
    }

    var totalElevationGain: Double {
        segments.reduce(0) { $0 + max(0, $1.elevationGain) }
    }

    var duration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }

    var trailDifficultyScore: Double {
        guard !segments.isEmpty else { return 0 }
        let avgEffort = segments.map(\.effortIndex).reduce(0, +) / Double(segments.count)
        return min(100, avgEffort / 2)
    }

    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? HikeSession.defaultName(from: startedAt) : name
    }

    static func defaultName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Hike \(formatter.string(from: date))"
    }
}
