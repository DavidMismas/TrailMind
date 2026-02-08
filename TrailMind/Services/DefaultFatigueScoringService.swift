import Foundation

struct DefaultFatigueScoringService: FatigueScoringService {
    func evaluate(
        previous: FatigueState,
        elapsed: TimeInterval,
        speed: Double,
        slopePercent: Double,
        heartRate: Double,
        cadence: Double
    ) -> FatigueState {
        let slopeLoad = max(0, slopePercent) * 0.45
        let cardioLoad = max(0, heartRate - 95) * 0.18
        let paceLoad = max(0, speed - 1.25) * 5
        let cadenceLoad = max(0, cadence - 1.5) * 10
        let durationLoad = elapsed / 150

        let rawScore = previous.score * 0.74 + slopeLoad + cardioLoad + paceLoad + cadenceLoad + durationLoad
        let score = min(100, max(0, rawScore))
        let energyRemaining = max(0, 1 - score / 100)
        let needsBreak = score > 68 || (heartRate > 165 && slopePercent > 6)

        let reason: String
        if needsBreak {
            reason = "Intensity is high for this terrain. Take a short break."
        } else if score > 45 {
            reason = "Steady load. Keep pace controlled on climbs."
        } else {
            reason = "Body load is manageable."
        }

        return FatigueState(score: score, energyRemaining: energyRemaining, needsBreak: needsBreak, reason: reason)
    }
}
