import Foundation

struct LiveMetricsSnapshot {
    let elapsed: TimeInterval
    let speed: Double
    let slopePercent: Double
    let heartRate: Double
    let cadence: Double
    let fatigue: FatigueState
    let terrain: TerrainType
}
