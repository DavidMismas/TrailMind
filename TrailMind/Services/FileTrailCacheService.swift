import Foundation
import CoreLocation

struct FileTrailCacheService: OfflineTrailCacheService {
    private struct CachedPoint: Codable {
        let timestamp: Date
        let latitude: Double
        let longitude: Double
        let altitude: Double
        let speed: Double
        let horizontalAccuracy: Double
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func cache(route: [LocationPoint], sessionID: UUID) {
        let payload = route.map {
            CachedPoint(
                timestamp: $0.timestamp,
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude,
                altitude: $0.altitude,
                speed: $0.speed,
                horizontalAccuracy: $0.horizontalAccuracy
            )
        }

        do {
            let data = try encoder.encode(payload)
            try data.write(to: url(for: sessionID), options: .atomic)
        } catch {
            return
        }
    }

    func load(sessionID: UUID) -> [LocationPoint] {
        do {
            let data = try Data(contentsOf: url(for: sessionID))
            let payload = try decoder.decode([CachedPoint].self, from: data)
            return payload.map {
                LocationPoint(
                    timestamp: $0.timestamp,
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    altitude: $0.altitude,
                    speed: $0.speed,
                    horizontalAccuracy: $0.horizontalAccuracy
                )
            }
        } catch {
            return []
        }
    }

    private func url(for sessionID: UUID) -> URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return directory.appendingPathComponent("trail-route-\(sessionID.uuidString).json")
    }
}
