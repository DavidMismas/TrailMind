import Foundation

struct TrailSegment: Identifiable, Codable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let duration: TimeInterval
    let distance: Double
    let elevationGain: Double
    let slopePercent: Double
    let averageSpeed: Double
    let heartRate: Double
    let cadence: Double
    let terrain: TerrainType

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        duration: TimeInterval,
        distance: Double,
        elevationGain: Double,
        slopePercent: Double,
        averageSpeed: Double,
        heartRate: Double,
        cadence: Double,
        terrain: TerrainType
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.distance = distance
        self.elevationGain = elevationGain
        self.slopePercent = slopePercent
        self.averageSpeed = averageSpeed
        self.heartRate = heartRate
        self.cadence = cadence
        self.terrain = terrain
    }

    var effortIndex: Double {
        let slopeLoad = max(0, slopePercent) * 0.9
        let heartRateLoad = heartRate * 0.2
        return slopeLoad + heartRateLoad + cadence * 0.05
    }
}

enum TerrainType: String, CaseIterable, Codable {
    case flat = "Flat"
    case climb = "Climb"
    case downhill = "Downhill"
    case technical = "Technical"
}
