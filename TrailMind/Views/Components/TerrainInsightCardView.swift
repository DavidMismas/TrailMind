import SwiftUI

struct TerrainInsightCardView: View {
    let terrain: TerrainType
    let pacingAdvice: String
    let safetyHint: String
    let aiInsight: String
    let isPremium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Terrain Intelligence")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(terrain.rawValue)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)
            }

            Text("Pacing: \(pacingAdvice)")
                .font(.subheadline)
                .foregroundStyle(.white)

            Text("Safety: \(safetyHint)")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.72))

            Divider()
                .overlay(Color.white.opacity(0.16))

            Text(isPremium ? aiInsight : "Premium unlocks Apple Intelligence interpretation.")
                .font(.subheadline)
                .foregroundStyle(isPremium ? Color.white : Color.white.opacity(0.68))
        }
        .trailCard()
    }
}
