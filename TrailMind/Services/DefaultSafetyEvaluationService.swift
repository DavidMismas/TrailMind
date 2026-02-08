import Foundation

struct DefaultSafetyEvaluationService: SafetyEvaluationService {
    func evaluate(
        fatigue: FatigueState,
        batteryLevel: Double,
        lastCheckIn: Date,
        elapsed: TimeInterval
    ) -> SafetyState {
        let checkInDue = Date().timeIntervalSince(lastCheckIn) > 20 * 60
        let lowBattery = batteryLevel < 0.2
        let overFatigued = fatigue.score > 80
        let returnHomeEnergyRisk = fatigue.energyRemaining < 0.25 && elapsed > 35 * 60

        let recommendation: String
        if overFatigued {
            recommendation = "High fatigue detected. Pause now and reassess return plan."
        } else if lowBattery {
            recommendation = "Battery low. Enable power saving and plan turn-back point."
        } else if checkInDue {
            recommendation = "Send check-in update to safety contact."
        } else if returnHomeEnergyRisk {
            recommendation = "Energy may be insufficient for return. Consider shortening route."
        } else {
            recommendation = "Safety status stable."
        }

        return SafetyState(
            checkInDue: checkInDue,
            lowBattery: lowBattery,
            overFatigued: overFatigued,
            returnHomeEnergyRisk: returnHomeEnergyRisk,
            recommendation: recommendation
        )
    }
}
