import Foundation
import CoreLocation

enum GPXExportError: Error {
    case emptyRoute
}

struct DefaultGPXExportService: GPXExportService {
    func export(session: HikeSession) throws -> URL {
        guard !session.route.isEmpty else {
            throw GPXExportError.emptyRoute
        }

        var gpx = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        gpx += "<gpx version=\"1.1\" creator=\"TrailMind\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n"
        gpx += "  <metadata><name>\(escape(session.displayName))</name></metadata>\n"
        gpx += "  <trk>\n"
        gpx += "    <name>\(escape(session.displayName))</name>\n"
        gpx += "    <trkseg>\n"

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for point in session.route {
            let latitude = String(format: "%.8f", point.coordinate.latitude)
            let longitude = String(format: "%.8f", point.coordinate.longitude)
            let elevation = String(format: "%.2f", point.altitude)
            let timestamp = formatter.string(from: point.timestamp)

            gpx += "      <trkpt lat=\"\(latitude)\" lon=\"\(longitude)\">\n"
            gpx += "        <ele>\(elevation)</ele>\n"
            gpx += "        <time>\(timestamp)</time>\n"
            gpx += "      </trkpt>\n"
        }

        gpx += "    </trkseg>\n"
        gpx += "  </trk>\n"
        gpx += "</gpx>\n"

        let baseName = session.displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")

        let filename = "\(baseName)-\(session.id.uuidString.prefix(8)).gpx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        guard let data = gpx.data(using: .utf8) else {
            throw GPXExportError.emptyRoute
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
