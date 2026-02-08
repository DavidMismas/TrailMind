import SwiftUI

struct EnergyBarView: View {
    let energyRemaining: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Energy")
                .font(.headline)
                .foregroundStyle(.white)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.22))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(energyColor)
                        .frame(width: geo.size.width * max(0, min(1, energyRemaining)))
                }
            }
            .frame(height: 14)

            Text("\(Int(energyRemaining * 100))% remaining")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.72))
        }
    }

    private var energyColor: Color {
        if energyRemaining > 0.5 { return .green }
        if energyRemaining > 0.25 { return .orange }
        return .red
    }
}
