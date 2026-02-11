import Foundation

struct FatigueState: Codable {
    var score: Double
    var accumulatedTrimp: Double
    var energyRemaining: Double
    var needsBreak: Bool
    var reason: String

    static let initial = FatigueState(score: 0, accumulatedTrimp: 0, energyRemaining: 1, needsBreak: false, reason: "Fresh start")

    enum CodingKeys: String, CodingKey {
        case score, accumulatedTrimp, energyRemaining, needsBreak, reason
    }

    init(score: Double, accumulatedTrimp: Double, energyRemaining: Double, needsBreak: Bool, reason: String) {
        self.score = score
        self.accumulatedTrimp = accumulatedTrimp
        self.energyRemaining = energyRemaining
        self.needsBreak = needsBreak
        self.reason = reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        score = try container.decode(Double.self, forKey: .score)
        accumulatedTrimp = try container.decodeIfPresent(Double.self, forKey: .accumulatedTrimp) ?? 0
        energyRemaining = try container.decode(Double.self, forKey: .energyRemaining)
        needsBreak = try container.decode(Bool.self, forKey: .needsBreak)
        reason = try container.decode(String.self, forKey: .reason)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(score, forKey: .score)
        try container.encode(accumulatedTrimp, forKey: .accumulatedTrimp)
        try container.encode(energyRemaining, forKey: .energyRemaining)
        try container.encode(needsBreak, forKey: .needsBreak)
        try container.encode(reason, forKey: .reason)
    }
}
