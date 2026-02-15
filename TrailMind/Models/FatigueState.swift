import Foundation

struct FatigueState: Codable {
    var score: Double
    var accumulatedTrimp: Double
    var energyRemaining: Double
    var needsBreak: Bool
    var reason: String
    var lastElapsedSeconds: TimeInterval
    var estimatedCaloriesBurned: Double
    var caloriesConsumed: Double

    static let initial = FatigueState(
        score: 0,
        accumulatedTrimp: 0,
        energyRemaining: 1,
        needsBreak: false,
        reason: "Fresh start",
        lastElapsedSeconds: 0,
        estimatedCaloriesBurned: 0,
        caloriesConsumed: 0
    )

    enum CodingKeys: String, CodingKey {
        case score
        case accumulatedTrimp
        case energyRemaining
        case needsBreak
        case reason
        case lastElapsedSeconds
        case estimatedCaloriesBurned
        case caloriesConsumed
    }

    init(
        score: Double,
        accumulatedTrimp: Double,
        energyRemaining: Double,
        needsBreak: Bool,
        reason: String,
        lastElapsedSeconds: TimeInterval = 0,
        estimatedCaloriesBurned: Double = 0,
        caloriesConsumed: Double = 0
    ) {
        self.score = score
        self.accumulatedTrimp = accumulatedTrimp
        self.energyRemaining = energyRemaining
        self.needsBreak = needsBreak
        self.reason = reason
        self.lastElapsedSeconds = lastElapsedSeconds
        self.estimatedCaloriesBurned = estimatedCaloriesBurned
        self.caloriesConsumed = caloriesConsumed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        score = try container.decode(Double.self, forKey: .score)
        accumulatedTrimp = try container.decodeIfPresent(Double.self, forKey: .accumulatedTrimp) ?? 0
        energyRemaining = try container.decodeIfPresent(Double.self, forKey: .energyRemaining) ?? max(0, 1 - score / 100)
        needsBreak = try container.decode(Bool.self, forKey: .needsBreak)
        reason = try container.decode(String.self, forKey: .reason)
        lastElapsedSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .lastElapsedSeconds) ?? 0
        estimatedCaloriesBurned = try container.decodeIfPresent(Double.self, forKey: .estimatedCaloriesBurned) ?? 0
        caloriesConsumed = try container.decodeIfPresent(Double.self, forKey: .caloriesConsumed) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(score, forKey: .score)
        try container.encode(accumulatedTrimp, forKey: .accumulatedTrimp)
        try container.encode(energyRemaining, forKey: .energyRemaining)
        try container.encode(needsBreak, forKey: .needsBreak)
        try container.encode(reason, forKey: .reason)
        try container.encode(lastElapsedSeconds, forKey: .lastElapsedSeconds)
        try container.encode(estimatedCaloriesBurned, forKey: .estimatedCaloriesBurned)
        try container.encode(caloriesConsumed, forKey: .caloriesConsumed)
    }
}
