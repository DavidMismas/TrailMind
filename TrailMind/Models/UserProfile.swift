import Foundation

enum FitnessCondition: String, Codable, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case moderate = "Moderate"
    case advanced = "Advanced"

    var id: String { rawValue }

    var fatigueMultiplier: Double {
        switch self {
        case .beginner: return 1.16
        case .moderate: return 1.0
        case .advanced: return 0.9
        }
    }
}

struct UserProfile: Codable {
    var age: Int
    var weightKg: Double
    var heightCm: Double
    var condition: FitnessCondition

    var fatigueMultiplier: Double {
        var multiplier = condition.fatigueMultiplier
        if age >= 55 { multiplier += 0.08 }
        if weightKg >= 95 { multiplier += 0.05 }
        return min(1.35, max(0.75, multiplier))
    }
}
