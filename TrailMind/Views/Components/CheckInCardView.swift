import SwiftUI

struct CheckInCardView: View {
    let isDue: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Safety Check-in")
                .font(.headline)
                .foregroundStyle(.white)

            Text(isDue ? "Check-in due now." : "Check-in up to date.")
                .font(.subheadline)
                .foregroundStyle(isDue ? .orange : Color.white.opacity(0.72))

            Button(action: action) {
                Text("Send Check-in")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(TrailTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trailCard()
    }
}
