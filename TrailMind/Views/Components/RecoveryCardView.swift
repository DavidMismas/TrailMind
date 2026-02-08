import SwiftUI

struct RecoveryCardView: View {
    let report: RecoveryReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recovery Model")
                .font(.headline)
                .foregroundStyle(.white)

            HStack {
                MetricTileView(title: "Muscle Load", value: "\(Int(report.muscleLoad))", footnote: "estimated")
                MetricTileView(title: "Ready In", value: "\(Int(report.recoveryHours))h", footnote: "recovery time")
            }

            MetricTileView(
                title: "Readiness",
                value: "\(Int(report.readinessScore))",
                footnote: "next hike readiness",
                tint: report.readinessScore > 60 ? .green : .orange
            )

            Text("Recommendations")
                .font(.subheadline.bold())
                .foregroundStyle(.white)

            ForEach(report.recommendations, id: \.self) { item in
                Text("• \(item)")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.72))
            }
        }
        .trailCard()
    }
}
