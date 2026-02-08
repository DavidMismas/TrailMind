import SwiftUI

struct FatigueCardView: View {
    let fatigue: FatigueState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fatigue Score")
                .font(.headline)
                .foregroundStyle(.white)

            Gauge(value: fatigue.score, in: 0...100) {
                Text("Fatigue")
            } currentValueLabel: {
                Text("\(Int(fatigue.score))")
                    .foregroundStyle(.white)
            }
            .tint(gaugeColor)

            Text(fatigue.reason)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.75))

            EnergyBarView(energyRemaining: fatigue.energyRemaining)

            if fatigue.needsBreak {
                Text("Break suggested now")
                    .font(.callout.bold())
                    .foregroundStyle(TrailTheme.warning)
            }
        }
        .trailCard()
    }

    private var gaugeColor: Color {
        if fatigue.score < 40 { return .green }
        if fatigue.score < 70 { return .orange }
        return .red
    }
}
