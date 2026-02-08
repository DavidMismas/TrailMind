import Foundation

struct FatigueState: Codable {
    var score: Double
    var energyRemaining: Double
    var needsBreak: Bool
    var reason: String

    static let initial = FatigueState(score: 0, energyRemaining: 1, needsBreak: false, reason: "Fresh start")
}
