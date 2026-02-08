import Foundation

struct LiveMetricsSnapshot {
    let elapsed: TimeInterval
    let distanceMeters: Double
    let elevationGain: Double
    let speed: Double
    let slopePercent: Double
    let heartRate: Double
    let cadence: Double
    let fatigue: FatigueState
    let terrain: TerrainType
    let trailDifficultyScore: Double
}
