import Foundation

enum Formatting {
    static func km(from meters: Double) -> String {
        String(format: "%.2f km", meters / 1000)
    }

    static func meters(_ value: Double) -> String {
        String(format: "%.0f m", value)
    }

    static func pace(from speed: Double) -> String {
        guard speed > 0 else { return "-" }
        let secondsPerKm = 1000 / speed
        let minutes = Int(secondsPerKm) / 60
        let seconds = Int(secondsPerKm) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    static func duration(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
