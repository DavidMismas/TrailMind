import SwiftUI
import MapKit

struct FullScreenMapScreen: View {
    let route: [LocationPoint]

    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition = .userLocation(
        followsHeading: false,
        fallback: .automatic
    )

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                UserAnnotation()

                if route.count > 1 {
                    MapPolyline(coordinates: route.map(\.coordinate))
                        .stroke(TrailTheme.accent, lineWidth: 5)
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
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Trail Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                updateCamera()
            }
            .onChange(of: route.count) { _, _ in
                updateCamera()
            }
        }
    }

    private func updateCamera() {
        guard let first = route.first, let last = route.last else {
            cameraPosition = .userLocation(
                followsHeading: false,
                fallback: .automatic
            )
            return
        }

        let center = CLLocationCoordinate2D(
            latitude: (first.coordinate.latitude + last.coordinate.latitude) / 2,
            longitude: (first.coordinate.longitude + last.coordinate.longitude) / 2
        )

        let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}
