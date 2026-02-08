import SwiftUI
import MapKit

struct RouteMapView: View {
    let route: [LocationPoint]
    var isTracking: Bool = false
    var onTap: (() -> Void)? = nil

    @State private var cameraPosition: MapCameraPosition = .userLocation(
        followsHeading: false,
        fallback: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        )
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Route")
                Spacer()
                Text("Tap to expand")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.68))
            }
                .font(.headline)
                .foregroundStyle(.white)

            Map(position: $cameraPosition) {
                UserAnnotation()

                if route.count > 1 {
                    MapPolyline(coordinates: route.map(\.coordinate))
                        .stroke(.blue, lineWidth: 4)
                }

                if let start = route.first {
                    Marker("Start", coordinate: start.coordinate)
                        .tint(.green)
                }

                if let end = route.last {
                    Marker("Now", coordinate: end.coordinate)
                        .tint(.orange)
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                if route.isEmpty && !isTracking {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.08))
                    Text("Start hike to draw live route")
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                updateCamera()
            }
            .onChange(of: route.count) { _, _ in
                updateCamera()
            }
            .mapControlVisibility(.hidden)
            .overlay {
                if let onTap {
                    Rectangle()
                        .fill(.black.opacity(0.001))
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onTap)
                }
            }
            .overlay(alignment: .topTrailing) {
                if route.isEmpty {
                    EmptyView()
                } else {
                    Text("Live")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.9))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(10)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.08))
            }
        }
    }

    private func updateCamera() {
        guard let first = route.first, let last = route.last else {
            cameraPosition = .userLocation(
                followsHeading: false,
                fallback: .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                )
            )
            return
        }

        let center = CLLocationCoordinate2D(
            latitude: (first.coordinate.latitude + last.coordinate.latitude) / 2,
            longitude: (first.coordinate.longitude + last.coordinate.longitude) / 2
        )

        let span = MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}
