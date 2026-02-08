import SwiftUI

struct MetricTileView: View {
    let title: String
    let value: String
    let footnote: String
    var tint: Color = TrailTheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.72))
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(tint)
            Text(footnote)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trailCard()
    }
}
