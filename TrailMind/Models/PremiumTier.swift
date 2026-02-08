import Foundation

enum PremiumTier {
    case free
    case premium

    var hasTerrainIntelligence: Bool {
        self == .premium
    }

    var hasRecoveryModel: Bool {
        self == .premium
    }

    var hasEnergyPrediction: Bool {
        self == .premium
    }
}
