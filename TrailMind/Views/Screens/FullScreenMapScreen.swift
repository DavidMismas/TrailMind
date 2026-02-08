import SwiftUI
import MapKit

struct FullScreenMapScreen: View {
    let route: [LocationPoint]

    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition = .userLocation(
        followsHeading: false,
        fallback: .automatic
    )
    @State private var autoCenterEnabled = true
    @State private var hasInitialFramedRoute = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                Map(position: $cameraPosition, interactionModes: .all) {
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
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0).onChanged { _ in
                        autoCenterEnabled = false
                    }
                )
                .mapControlVisibility(.hidden)

                Button {
                    autoCenterEnabled = true
                    updateCamera(force: true)
                } label: {
                    Image(systemName: "location.fill")
                        .font(.headline.bold())
                        .padding(10)
                        .background(Color.white.opacity(0.9))
                        .foregroundStyle(.black)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.top, 14)
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
                updateCamera(force: true)
            }
            .onChange(of: route.count) { _, newCount in
                if newCount == 0 {
                    hasInitialFramedRoute = false
                    autoCenterEnabled = true
                    updateCamera(force: true)
                    return
                }

                if !hasInitialFramedRoute {
                    hasInitialFramedRoute = true
                    updateCamera(force: true)
                    return
                }

                updateCamera(force: false)
            }
        }
    }

    private func updateCamera(force: Bool) {
        if !force && !autoCenterEnabled { return }

        guard !route.isEmpty else {
            cameraPosition = .userLocation(
                followsHeading: false,
                fallback: .automatic
            )
            return
        }

        if route.count == 1, let first = route.first {
            let region = MKCoordinateRegion(
                center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            cameraPosition = .region(region)
            return
        }

        if !force && route.count % 4 != 0 {
            return
        }

        var rect = MKMapRect.null
        for point in route {
            let mapPoint = MKMapPoint(point.coordinate)
            let pointRect = MKMapRect(origin: mapPoint, size: MKMapSize(width: 0, height: 0))
            rect = rect.isNull ? pointRect : rect.union(pointRect)
        }

        guard !rect.isNull else { return }
        let padding = max(rect.size.width, rect.size.height) * 0.35
        let paddedRect = rect.insetBy(dx: -padding, dy: -padding)
        cameraPosition = .rect(paddedRect)
    }
}
