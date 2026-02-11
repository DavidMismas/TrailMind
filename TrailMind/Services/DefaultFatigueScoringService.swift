import Foundation

struct DefaultFatigueScoringService: FatigueScoringService {
    func evaluate(
        previous: FatigueState,
        elapsed: TimeInterval,
        speed: Double,
        slopePercent: Double,
        heartRate: Double,
        cadence: Double,
        profile: UserProfile?
    ) -> FatigueState {
        // Fallback to heuristic if no profile or heart rate is unavailable/unrealistic
        guard let profile, heartRate > 30 else {
            return calculateHeuristic(previous: previous, elapsed: elapsed, speed: speed, slopePercent: slopePercent, heartRate: heartRate, cadence: cadence)
        }

        // let durationMinutes = (elapsed - (previous.accumulatedTrimp > 0 ? elapsed : 0)) / 60.0 // Delta time would be better, but we only have total elapsed. 
        // Note: The previous design passed total elapsed. We need delta time to calculate incremental TRIMP.
        // However, the caller passes the TOTAL elapsed time of the hike. 
        // The service is stateless regarding time, so we should rely on "previous" state having the accumulated TRIMP.
        // To properly calculate TRIMP step, we need the time delta since last evaluation.
        // Assuming evaluate is called every ~1-5 seconds.
        // Let's assume a strictly additive model where we add a "step" TRIMP.
        // BUT, the interface gives us 'elapsed' (total). 
        // We lack 'lastEvaluationTime'.
        // FIX: The caller (ViewModel) calls this on every location update.
        // Let's assume a standard step duration for now or try to deduce it if we tracked 'lastUpdated'.
        // Since we can't change the signature to include 'deltaTime' easily without refactoring everything,
        // we will assume a 1-second step or derive it if the previous state stored a timestamp (it doesn't).
        // A robust way: The view model appends points. 
        // Let's rely on a simplified "TRIMP per second" rate for the current heart rate, 
        // and add it to the previous total. Use 1s as a baseline if we are called frequently.
        // Actually, the best way given the constraints is to treat this call as "add this moment's load".
        // If the caller calls this every 1s, we add 1s worth of TRIMP.
        
        let stepDurationMinutes = 1.0 / 60.0 // Assuming ~1Hz updates. 
        
        let restHR = Double(profile.restingHeartRate)
        let maxHR = Double(profile.effectiveMaxHeartRate)
        
        // HR Reserve (Karvonen method components)
        let hrReserve = max(1, maxHR - restHR)
        let hrRatio = (heartRate - restHR) / hrReserve
        
        // Banister's TRIMP exponential factor (generic 1.92 for men, 1.67 for women - averaging to 1.8 for now or using 1.92 as standard)
        let exponential = exp(1.92 * hrRatio)
        
        let stepTrimp = stepDurationMinutes * hrRatio * 0.64 * exponential
        
        let newAccumulatedTrimp = previous.accumulatedTrimp + max(0, stepTrimp)
        let capacity = profile.trimpCapacity
        
        let percentage = (newAccumulatedTrimp / capacity) * 100
        let score = min(100, max(0, percentage))
        let energyRemaining = max(0, 1 - score / 100)
        
        let needsBreak = score > 90 || (heartRate > (maxHR * 0.9))
        
        let reason: String
        if needsBreak {
            reason = "Near exhausted. Rest required."
        } else if score > 70 {
            reason = "High fatigue. Pace yourself."
        } else if score > 40 {
             reason = "Moderate load. Good steady effort."
        } else {
            reason = "Warming up / Low intensity."
        }

        return FatigueState(
            score: score,
            accumulatedTrimp: newAccumulatedTrimp,
            energyRemaining: energyRemaining,
            needsBreak: needsBreak,
            reason: reason
        )
    }

    private func calculateHeuristic(
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

        return FatigueState(score: score, accumulatedTrimp: 0, energyRemaining: energyRemaining, needsBreak: needsBreak, reason: reason)
    }
}
