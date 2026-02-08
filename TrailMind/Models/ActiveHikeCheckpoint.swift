import Foundation

struct ActiveHikeCheckpoint: Codable {
    let startedAt: Date
    let lastCheckIn: Date
    let route: [LocationPoint]
    let segments: [TrailSegment]
    let fatigueState: FatigueState
    let safetyState: SafetyState
    let cadence: Double
    let speed: Double
    let slopePercent: Double
    let batteryLevel: Double
    let terrain: TerrainType
    let pacingAdvice: String
    let terrainSafetyHint: String
    let aiInsight: String
    let currentAltitude: Double
}
