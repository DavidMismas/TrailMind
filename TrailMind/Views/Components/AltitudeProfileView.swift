import SwiftUI
import CoreLocation

struct AltitudeProfileView: View {
    let route: [LocationPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Altitude Profile")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(distanceLabel)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.7))
            }

            if profile.count > 1 {
                GeometryReader { geometry in
                    let minAltitude = profile.map(\.altitude).min() ?? 0
                    let maxAltitude = profile.map(\.altitude).max() ?? 0
                    let altitudeRange = max(1, maxAltitude - minAltitude)
                    let totalDistance = max(1, profile.last?.distance ?? 1)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.07))

                        Path { path in
                            for (index, point) in profile.enumerated() {
                                let x = (point.distance / totalDistance) * geometry.size.width
                                let normalizedY = (point.altitude - minAltitude) / altitudeRange
                                let y = geometry.size.height - normalizedY * geometry.size.height
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(TrailTheme.accent, lineWidth: 3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Max \(Int(maxAltitude))m")
                            Text("Min \(Int(minAltitude))m")
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.68))
                        .padding(8)
                    }
                }
                .frame(height: 160)
            } else {
                Text("Move to build altitude profile")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 80)
            }
        }
        .trailCard()
    }

    private var profile: [AltitudePoint] {
        guard route.count > 1 else { return route.map { AltitudePoint(distance: 0, altitude: $0.altitude) } }

        var total: Double = 0
        var points: [AltitudePoint] = [AltitudePoint(distance: 0, altitude: route[0].altitude)]
        points.reserveCapacity(route.count)

        for index in 1..<route.count {
            let previous = route[index - 1]
            let current = route[index]
            let segmentDistance = CLLocation(
                latitude: previous.coordinate.latitude,
                longitude: previous.coordinate.longitude
            ).distance(
                from: CLLocation(
                    latitude: current.coordinate.latitude,
                    longitude: current.coordinate.longitude
                )
            )
            total += max(0, segmentDistance)
            points.append(AltitudePoint(distance: total, altitude: current.altitude))
        }

        if points.count > 250 {
            let step = max(1, points.count / 250)
            points = points.enumerated().compactMap { idx, value in
                idx % step == 0 || idx == points.count - 1 ? value : nil
            }
        }

        return points
    }

    private var distanceLabel: String {
        guard let last = profile.last else { return "0 km" }
        return String(format: "%.2f km", last.distance / 1000)
    }
}

private struct AltitudePoint {
    let distance: Double
    let altitude: Double
}
