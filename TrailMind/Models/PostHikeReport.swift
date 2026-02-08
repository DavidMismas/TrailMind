import Foundation

struct PostHikeReport {
    let insights: [PerformanceInsight]
    let recovery: RecoveryReport
    let fatigueToleranceTrend: String
    let climbEfficiency: Double
    let terrainAdaptation: Double
}
