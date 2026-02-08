import SwiftUI

struct InsightsListView: View {
    let insights: [PerformanceInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Performance Breakdown")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(insights) { insight in
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text(insight.detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                )
            }
        }
        .trailCard()
    }
}
