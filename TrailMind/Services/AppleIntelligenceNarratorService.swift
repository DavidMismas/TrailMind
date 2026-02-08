import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AppleIntelligenceNarratorService: AppleIntelligenceService {
    func liveInsight(from snapshot: LiveMetricsSnapshot) async -> String {
        let fatigueText: String
        if snapshot.fatigue.score > 75 {
            fatigueText = "Current pace on this section is likely to cause early fatigue."
        } else if snapshot.fatigue.score > 45 {
            fatigueText = "Moderate load detected, keep cadence smooth to preserve energy."
        } else {
            fatigueText = "Load is under control for now."
        }

        switch snapshot.terrain {
        case .climb:
            return "\(fatigueText) On this climb, reduce pace by about 10% for better endurance."
        case .downhill:
            return "\(fatigueText) Keep downhill steps short to reduce joint stress."
        case .technical:
            return "\(fatigueText) Technical terrain detected, prioritize stability over speed."
        case .flat:
            return "\(fatigueText) Flat section is a good place to recover rhythm."
        }
    }
}
