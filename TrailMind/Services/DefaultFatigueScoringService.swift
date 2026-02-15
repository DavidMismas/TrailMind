import Foundation

struct DefaultFatigueScoringService: FatigueScoringService {
    private let fallbackWeightKg: Double = 75
    private let maxStepSeconds: TimeInterval = 15
    private let fuelUptakeEfficiency: Double = 0.92

    func evaluate(
        previous: FatigueState,
        elapsed: TimeInterval,
        speed: Double,
        slopePercent: Double,
        heartRate: Double,
        cadence: Double,
        profile: UserProfile?
    ) -> FatigueState {
        let deltaSeconds = stepDeltaSeconds(previous: previous, elapsed: elapsed)
        let caloriesConsumed = max(0, previous.caloriesConsumed)
        let caloriesBurnedStep = estimateCaloriesBurned(
            deltaSeconds: deltaSeconds,
            speed: speed,
            slopePercent: slopePercent,
            weightKg: profile?.weightKg ?? fallbackWeightKg
        )
        let totalCaloriesBurned = previous.estimatedCaloriesBurned + caloriesBurnedStep

        guard let profile, heartRate > 30 else {
            return calculateHeuristic(
                previous: previous,
                elapsed: elapsed,
                deltaSeconds: deltaSeconds,
                speed: speed,
                slopePercent: slopePercent,
                cadence: cadence,
                caloriesConsumed: caloriesConsumed,
                totalCaloriesBurned: totalCaloriesBurned,
                profile: profile
            )
        }

        let stepDurationMinutes = deltaSeconds / 60.0
        let restHR = Double(profile.restingHeartRate)
        let maxHR = Double(profile.effectiveMaxHeartRate)

        let hrReserve = max(1, maxHR - restHR)
        let boundedHeartRate = min(max(heartRate, restHR), maxHR * 1.05)
        let hrRatio = min(1.2, max(0, (boundedHeartRate - restHR) / hrReserve))
        let exponential = exp(1.92 * hrRatio)

        let stepTrimp = max(0, stepDurationMinutes * hrRatio * 0.64 * exponential)
        let newAccumulatedTrimp = previous.accumulatedTrimp + stepTrimp
        let capacity = adjustedCapacity(for: profile)

        let trimpScore = min(100, max(0, (newAccumulatedTrimp / capacity) * 100))
        let energyRemaining = energyRemaining(
            profile: profile,
            caloriesBurned: totalCaloriesBurned,
            caloriesConsumed: caloriesConsumed
        )
        let energyPressureScore = (1 - energyRemaining) * 100
        let score = min(100, max(0, trimpScore * 0.75 + energyPressureScore * 0.25))
        let needsBreak = score > 88 || (boundedHeartRate > (maxHR * 0.9)) || energyRemaining < 0.15
        let reason = reasonText(score: score, energyRemaining: energyRemaining, hasHeartRate: true)

        return FatigueState(
            score: score,
            accumulatedTrimp: newAccumulatedTrimp,
            energyRemaining: energyRemaining,
            needsBreak: needsBreak,
            reason: reason,
            lastElapsedSeconds: elapsed,
            estimatedCaloriesBurned: totalCaloriesBurned,
            caloriesConsumed: caloriesConsumed
        )
    }

    private func calculateHeuristic(
        previous: FatigueState,
        elapsed: TimeInterval,
        deltaSeconds: TimeInterval,
        speed: Double,
        slopePercent: Double,
        cadence: Double,
        caloriesConsumed: Double,
        totalCaloriesBurned: Double,
        profile: UserProfile?
    ) -> FatigueState {
        let stepMinutes = deltaSeconds / 60.0
        let speedTerm = max(0, speed - 0.8) * 3.2
        let slopeTerm = max(0, slopePercent) * 0.22
        let cadenceTerm = max(0, cadence - 1.2) * 2.4
        let pseudoIntensity = min(1.1, max(0.12, (speedTerm + slopeTerm + cadenceTerm) / 8.5))

        let stepLoad = max(0, stepMinutes * pseudoIntensity * 0.64 * exp(1.7 * pseudoIntensity))
        let newAccumulatedTrimp = previous.accumulatedTrimp + stepLoad
        let capacity = adjustedCapacity(for: profile)

        let trimpScore = min(100, max(0, (newAccumulatedTrimp / capacity) * 100))
        let energyRemaining = energyRemaining(
            profile: profile,
            caloriesBurned: totalCaloriesBurned,
            caloriesConsumed: caloriesConsumed
        )
        let energyPressureScore = (1 - energyRemaining) * 100
        let score = min(100, max(0, trimpScore * 0.8 + energyPressureScore * 0.2))
        let needsBreak = score > 82 || (energyRemaining < 0.12 && elapsed > 25 * 60)
        let reason = reasonText(score: score, energyRemaining: energyRemaining, hasHeartRate: false)

        return FatigueState(
            score: score,
            accumulatedTrimp: newAccumulatedTrimp,
            energyRemaining: energyRemaining,
            needsBreak: needsBreak,
            reason: reason,
            lastElapsedSeconds: elapsed,
            estimatedCaloriesBurned: totalCaloriesBurned,
            caloriesConsumed: caloriesConsumed
        )
    }

    private func stepDeltaSeconds(previous: FatigueState, elapsed: TimeInterval) -> TimeInterval {
        if previous.lastElapsedSeconds <= 0, previous.accumulatedTrimp > 0 {
            return 1
        }

        let delta = elapsed - previous.lastElapsedSeconds
        guard delta.isFinite else { return 0 }
        if delta <= 0 { return 0 }
        return min(maxStepSeconds, delta)
    }

    private func adjustedCapacity(for profile: UserProfile?) -> Double {
        guard let profile else { return 220 }
        let multiplier = min(1.35, max(0.75, profile.fatigueMultiplier))
        let adjusted = profile.trimpCapacity / multiplier
        return min(420, max(120, adjusted))
    }

    private func energyRemaining(
        profile: UserProfile?,
        caloriesBurned: Double,
        caloriesConsumed: Double
    ) -> Double {
        let baselineReserve = baselineReserveKcal(profile: profile)
        let effectiveIntake = max(0, caloriesConsumed) * fuelUptakeEfficiency
        let remaining = (baselineReserve + effectiveIntake - max(0, caloriesBurned)) / baselineReserve
        return min(1, max(0, remaining))
    }

    private func baselineReserveKcal(profile: UserProfile?) -> Double {
        let weight = profile?.weightKg ?? fallbackWeightKg
        var reserve = weight * 18

        if let profile {
            switch profile.condition {
            case .beginner:
                reserve -= 120
            case .moderate:
                break
            case .advanced:
                reserve += 180
            }
            if profile.age >= 60 {
                reserve -= 80
            } else if profile.age <= 30 {
                reserve += 80
            }
        }

        return min(2600, max(1100, reserve))
    }

    private func estimateCaloriesBurned(
        deltaSeconds: TimeInterval,
        speed: Double,
        slopePercent: Double,
        weightKg: Double
    ) -> Double {
        let minutes = deltaSeconds / 60
        guard minutes > 0 else { return 0 }

        let speedMPerMin = max(0, speed) * 60
        let grade = min(0.25, max(-0.25, slopePercent / 100))
        let horizontalCost = 0.1 * speedMPerMin
        let verticalCost: Double
        if grade >= 0 {
            verticalCost = 1.8 * speedMPerMin * grade
        } else {
            verticalCost = 0.5 * speedMPerMin * abs(grade)
        }
        let vo2 = max(3.5, 3.5 + horizontalCost + verticalCost)
        let kcalPerMinute = min(18, max(1, (vo2 * max(35, weightKg)) / 200))
        return kcalPerMinute * minutes
    }

    private func reasonText(score: Double, energyRemaining: Double, hasHeartRate: Bool) -> String {
        if energyRemaining < 0.12 {
            return "Fuel reserve is very low. Refuel and rest now."
        }
        if score > 85 {
            return hasHeartRate ? "Near exhaustion. Slow down and recover." : "High fatigue risk. Slow down and take a break."
        }
        if score > 65 {
            return "High load. Keep effort steady and consider a short pause."
        }
        if score > 40 {
            return "Moderate load. Keep cadence smooth and fueling regular."
        }
        return "Load is controlled."
    }
}
