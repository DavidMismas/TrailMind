import SwiftUI

enum TrailTheme {
    static let accent = Color(red: 0.12, green: 0.51, blue: 0.44)
    static let warning = Color(red: 0.86, green: 0.45, blue: 0.22)

    static let background = LinearGradient(
        colors: [
            Color(red: 0.06, green: 0.12, blue: 0.15),
            Color(red: 0.11, green: 0.2, blue: 0.21),
            Color(red: 0.16, green: 0.26, blue: 0.21)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardFill = LinearGradient(
        colors: [
            Color.white.opacity(0.18),
            Color.white.opacity(0.09)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct TrailCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(TrailTheme.cardFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
    }
}

extension View {
    func trailCard() -> some View {
        modifier(TrailCardModifier())
    }
}
