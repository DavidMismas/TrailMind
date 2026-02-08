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

            Button("Send Check-in", action: action)
                .buttonStyle(.borderedProminent)
                .tint(TrailTheme.accent)
        }
        .trailCard()
    }
}
