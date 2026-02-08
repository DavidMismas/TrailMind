import Foundation

struct SafetyState: Codable {
    var checkInDue: Bool
    var lowBattery: Bool
    var overFatigued: Bool
    var returnHomeEnergyRisk: Bool
    var recommendation: String

    static let calm = SafetyState(
        checkInDue: false,
        lowBattery: false,
        overFatigued: false,
        returnHomeEnergyRisk: false,
        recommendation: "All good"
    )
}
