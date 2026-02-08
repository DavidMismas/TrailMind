import SwiftUI

struct PremiumFeatureCardView: View {
    let title: String
    let description: String
    let enabled: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: enabled ? "checkmark.seal.fill" : "lock.fill")
                .foregroundStyle(enabled ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            Spacer()
        }
        .trailCard()
    }
}
