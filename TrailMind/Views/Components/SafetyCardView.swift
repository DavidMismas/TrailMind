import SwiftUI

struct SafetyCardView: View {
    let state: SafetyState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Safety")
                .font(.headline)
                .foregroundStyle(.white)

            Label(state.recommendation, systemImage: iconName)
                .font(.subheadline)
                .foregroundStyle(iconColor)

            HStack {
                tag("Check-in", active: state.checkInDue)
                tag("Battery", active: state.lowBattery)
                tag("Fatigue", active: state.overFatigued || state.returnHomeEnergyRisk)
            }
        }
        .trailCard()
    }

    private var iconName: String {
        if state.overFatigued { return "exclamationmark.triangle.fill" }
        if state.lowBattery { return "battery.25" }
        if state.checkInDue { return "person.crop.circle.badge.exclamationmark" }
        return "checkmark.shield.fill"
    }

    private var iconColor: Color {
        if state.overFatigued || state.returnHomeEnergyRisk { return .red }
        if state.lowBattery || state.checkInDue { return .orange }
        return .green
    }

    private func tag(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(active ? Color.red.opacity(0.22) : Color.white.opacity(0.12))
            .foregroundStyle(Color.white.opacity(0.9))
            .clipShape(Capsule())
    }
}
