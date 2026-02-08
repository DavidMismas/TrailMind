import Foundation
import CoreLocation

struct LocationPoint: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let coordinate: CLLocationCoordinate2D
    let altitude: Double
    let speed: Double
    let horizontalAccuracy: Double

    init(location: CLLocation) {
        self.id = UUID()
        self.timestamp = location.timestamp
        self.coordinate = location.coordinate
        self.altitude = location.altitude
        self.speed = max(location.speed, 0)
        self.horizontalAccuracy = location.horizontalAccuracy
    }

    init(
        id: UUID = UUID(),
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        altitude: Double,
        speed: Double,
        horizontalAccuracy: Double = 5
    ) {
        self.id = id
        self.timestamp = timestamp
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.altitude = altitude
        self.speed = speed
        self.horizontalAccuracy = horizontalAccuracy
    }

    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case latitude
        case longitude
        case altitude
        case speed
        case horizontalAccuracy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        altitude = try container.decode(Double.self, forKey: .altitude)
        speed = try container.decode(Double.self, forKey: .speed)
        horizontalAccuracy = try container.decode(Double.self, forKey: .horizontalAccuracy)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(altitude, forKey: .altitude)
        try container.encode(speed, forKey: .speed)
        try container.encode(horizontalAccuracy, forKey: .horizontalAccuracy)
    }
}
