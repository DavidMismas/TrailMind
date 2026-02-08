import SwiftUI
import MapKit

struct RouteMapView: View {
    let route: [LocationPoint]
    var isTracking: Bool = false
    var onExpand: (() -> Void)? = nil

    @State private var cameraPosition: MapCameraPosition = .userLocation(
        followsHeading: false,
        fallback: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        )
    )
    @State private var hasInitialFramedRoute = false
    @State private var autoCenterEnabled = true
    @State private var isProgrammaticCameraChange = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Route")
                Spacer()
                if let onExpand {
                    Button(action: onExpand) {
                        Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.14))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.headline)
            .foregroundStyle(.white)

            ZStack(alignment: .topTrailing) {
                Map(position: $cameraPosition, interactionModes: .all) {
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
                .onAppear {
                    frameRoute(force: true)
                }
                .onChange(of: route.count) { _, newCount in
                    if newCount == 0 {
                        hasInitialFramedRoute = false
                        autoCenterEnabled = true
                        frameRoute(force: true)
                        return
                    }

                    if !hasInitialFramedRoute {
                        hasInitialFramedRoute = true
                        frameRoute(force: true)
                        return
                    }

                    frameRoute(force: false)
                }
                .onMapCameraChange(frequency: .onEnd) { _ in
                    if isProgrammaticCameraChange {
                        isProgrammaticCameraChange = false
                        return
                    }
                    autoCenterEnabled = false
                }
                .mapControlVisibility(.hidden)

                VStack(spacing: 8) {
                    if isTracking {
                        Text("Live")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.9))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    Button {
                        if isTracking {
                            autoCenterEnabled = true
                            frameRoute(force: true)
                        } else {
                            autoCenterEnabled = false
                            centerOnUserLocation()
                        }
                    } label: {
                        if isTracking {
                            Image(systemName: "location.fill")
                                .font(.footnote.bold())
                                .padding(8)
                                .background(Color.white.opacity(0.9))
                                .foregroundStyle(.black)
                                .clipShape(Circle())
                        } else {
                            Label("My Location", systemImage: "location.fill")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.9))
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
            }
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.08))
            }
        }
    }

    private func frameRoute(force: Bool) {
        if !force && !autoCenterEnabled { return }

        guard !route.isEmpty else {
            centerOnUserLocation()
            return
        }

        if route.count == 1, let first = route.first {
            let region = MKCoordinateRegion(
                center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            setCameraPosition(.region(region))
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
        setCameraPosition(.rect(paddedRect))
    }

    private func centerOnUserLocation() {
        let fallbackCenter = route.last?.coordinate
            ?? CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090)
        let fallbackRegion = MKCoordinateRegion(
            center: fallbackCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )

        setCameraPosition(
            .userLocation(
                followsHeading: false,
                fallback: .region(fallbackRegion)
            )
        )
    }

    private func setCameraPosition(_ position: MapCameraPosition) {
        isProgrammaticCameraChange = true
        cameraPosition = position
    }
}
