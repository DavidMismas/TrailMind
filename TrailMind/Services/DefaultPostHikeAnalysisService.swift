import Foundation

struct DefaultPostHikeAnalysisService: PostHikeAnalysisService {
    func buildReport(from session: HikeSession, historicalSessions: [HikeSession]) -> PostHikeReport {
        let climbSegments = session.segments.filter { $0.terrain == .climb }
        let avgClimbSpeed = climbSegments.map(\.averageSpeed).average
        let climbEfficiency = min(100, max(0, avgClimbSpeed * 48))

        let terrainVariety = Set(session.segments.map(\.terrain)).count
        let terrainAdaptation = min(100, Double(terrainVariety) * 25)

        var insights = [PerformanceInsight]()

        if let mostIntense = session.segments.max(by: { $0.effortIndex < $1.effortIndex }) {
            let offsetMinutes = max(0, mostIntense.startedAt.timeIntervalSince(session.startedAt) / 60)
            insights.append(
                PerformanceInsight(
                    title: "Peak Load Segment",
                    detail: "Highest effort was around \(format(minutes: offsetMinutes)). Consider a short pause before similar climbs."
                )
            )
        }

        if session.finalFatigue.score > 70 {
            insights.append(
                PerformanceInsight(
                    title: "Pacing",
                    detail: "You pushed hard relative to terrain. Slower first climb should reduce late fatigue drop."
                )
            )
        } else {
            insights.append(
                PerformanceInsight(
                    title: "Pacing",
                    detail: "Your pacing matched terrain load well for most segments."
                )
            )
        }

        let muscleLoad = min(100, session.trailDifficultyScore + session.finalFatigue.score * 0.4)
        let recoveryHours = max(8, muscleLoad * 0.45)
        let readinessScore = max(0, 100 - muscleLoad * 0.7)

        let recovery = RecoveryReport(
            muscleLoad: muscleLoad,
            recoveryHours: recoveryHours,
            readinessScore: readinessScore,
            recommendations: recommendations(for: muscleLoad)
        )

        let fatigueToleranceTrend = trendText(current: session.finalFatigue.score, historical: historicalSessions)

        return PostHikeReport(
            insights: insights,
            recovery: recovery,
            fatigueToleranceTrend: fatigueToleranceTrend,
            climbEfficiency: climbEfficiency,
            terrainAdaptation: terrainAdaptation
        )
    }

    private func trendText(current: Double, historical: [HikeSession]) -> String {
        guard !historical.isEmpty else { return "Baseline established" }
        let historicalAvg = historical.map(\.finalFatigue.score).average
        if current < historicalAvg {
            return "Improving fatigue tolerance"
        }
        if current > historicalAvg + 8 {
            return "Higher fatigue than usual"
        }
        return "Stable fatigue tolerance"
    }

    private func recommendations(for muscleLoad: Double) -> [String] {
        if muscleLoad > 70 {
            return ["Light walk", "Hydration", "Longer sleep", "Gentle stretching"]
        }
        if muscleLoad > 45 {
            return ["Mobility", "Easy walk", "Protein-rich meal"]
        }
        return ["Optional easy walk", "Normal routine"]
    }

    private func format(minutes: Double) -> String {
        "\(Int(minutes.rounded())) min"
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
