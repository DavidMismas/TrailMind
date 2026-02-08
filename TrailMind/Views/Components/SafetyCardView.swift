import SwiftUI

struct SafetyCardView: View {
    let state: SafetyState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Safety")
                .font(.headline)
                .foregroundStyle(.white)

            Label(state.recommendation, systemImage: iconName)
                .font(.subheadline)
                .foregroundStyle(iconColor)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                statusPill(
                    title: "Check-in",
                    value: state.checkInDue ? "Due" : "OK",
                    color: state.checkInDue ? .orange : .green
                )
                statusPill(
                    title: "Battery",
                    value: state.lowBattery ? "Low" : "OK",
                    color: state.lowBattery ? .orange : .green
                )
                statusPill(
                    title: "Fatigue",
                    value: (state.overFatigued || state.returnHomeEnergyRisk) ? "High" : "OK",
                    color: (state.overFatigued || state.returnHomeEnergyRisk) ? .red : .green
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func statusPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.68))
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(color.opacity(0.45), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
