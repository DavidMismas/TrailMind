//
//  TrailMindLiveActivityExtension.swift
//  TrailMindLiveActivityExtension
//
//  Created by David Misma on 8. 2. 26.
//

import WidgetKit
import SwiftUI
import ActivityKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), mirror: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), mirror: resolvedState())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = SimpleEntry(date: Date(), mirror: resolvedState())
        let refreshDate = Date().addingTimeInterval(15)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func resolvedState() -> SharedMirrorState? {
        if let mirror = SharedMirrorStore.load(), mirror.isTracking {
            return mirror
        }

        if #available(iOS 16.2, *) {
            if let activity = Activity<TrailMindHikeLiveActivityAttributes>.activities.first {
                return SharedMirrorState(
                    startedAt: activity.attributes.startedAt,
                    elapsedSeconds: activity.content.state.elapsedSeconds,
                    distanceMeters: activity.content.state.distanceMeters,
                    currentAltitudeMeters: 0,
                    elevationGainMeters: 0,
                    altitudeSamples: [],
                    isTracking: true,
                    updatedAt: Date()
                )
            }
        }
        return SharedMirrorStore.load()
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let mirror: SharedMirrorState?
}

struct TrailMindLiveActivityExtensionEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumOrLargeContent(graphHeight: 58, compact: true)
        case .systemLarge:
            mediumOrLargeContent(graphHeight: 150, compact: false)
        default:
            smallContent
        }
    }

    @ViewBuilder
    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.hiking")
                Text("TrailMind")
                    .font(.headline)
            }

            if let mirror = entry.mirror, mirror.isTracking {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(mirror.startedAt, style: .timer)
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Distance")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(distanceText(mirror.distanceMeters))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            } else {
                Text("No active hike")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func mediumOrLargeContent(graphHeight: CGFloat, compact: Bool) -> some View {
        if let mirror = entry.mirror, mirror.isTracking {
            VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                HStack {
                    Label("TrailMind", systemImage: "figure.hiking")
                        .font((compact ? Font.subheadline : Font.headline).weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, compact ? 6 : 8)
                        .padding(.vertical, compact ? 3 : 4)
                        .background(.green.opacity(0.2), in: Capsule())
                }

                HStack(alignment: .top, spacing: compact ? 8 : 16) {
                    metricBlock(
                        title: "Duration",
                        value: Text(mirror.startedAt, style: .timer),
                        detail: nil,
                        compact: compact
                    )

                    metricBlock(
                        title: "Distance",
                        value: Text(distanceText(mirror.distanceMeters)),
                        detail: nil,
                        compact: compact
                    )

                    metricBlock(
                        title: "Altitude",
                        value: Text(altitudeText(mirror.currentAltitudeMeters)),
                        detail: Text("Gain \(altitudeText(mirror.elevationGainMeters))"),
                        compact: compact
                    )
                }

                AltitudeProfileGraphView(
                    samples: mirror.altitudeSamples,
                    height: graphHeight,
                    showScaleLabels: !compact
                )
            }
            .padding(compact ? 10 : 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("TrailMind", systemImage: "figure.hiking")
                    .font(.headline)
                Text("No active hike")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Start recording to show live duration, altitude, distance, and profile graph.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func distanceText(_ meters: Double) -> String {
        String(format: "%.2f km", max(0, meters) / 1000)
    }

    private func altitudeText(_ meters: Double) -> String {
        "\(Int(meters.rounded())) m"
    }

    @ViewBuilder
    private func metricBlock(
        title: String,
        value: Text,
        detail: Text?,
        compact: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            value
                .font((compact ? Font.title3 : Font.headline).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            if let detail {
                detail
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AltitudeProfileGraphView: View {
    let samples: [SharedMirrorState.AltitudeSample]
    let height: CGFloat
    let showScaleLabels: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))

            if samples.count > 1 {
                GeometryReader { geometry in
                    let points = chartPoints(in: geometry.size)
                    Canvas { context, size in
                        guard points.count > 1 else { return }

                        var area = Path()
                        area.move(to: CGPoint(x: points[0].x, y: size.height))
                        area.addLine(to: points[0])
                        for point in points.dropFirst() {
                            area.addLine(to: point)
                        }
                        if let last = points.last {
                            area.addLine(to: CGPoint(x: last.x, y: size.height))
                        }
                        area.closeSubpath()
                        context.fill(
                            area,
                            with: .linearGradient(
                                Gradient(colors: [Color.mint.opacity(0.35), Color.mint.opacity(0.06)]),
                                startPoint: CGPoint(x: 0, y: 0),
                                endPoint: CGPoint(x: 0, y: size.height)
                            )
                        )

                        var line = Path()
                        line.move(to: points[0])
                        for point in points.dropFirst() {
                            line.addLine(to: point)
                        }
                        context.stroke(line, with: .color(.mint), lineWidth: 2.2)
                    }

                    if showScaleLabels {
                        VStack {
                            HStack {
                                Text(topAltitudeLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            Spacer()
                            HStack {
                                Text(bottomAltitudeLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(distanceLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                }
                .padding(4)
            } else {
                Text("Waiting for altitude samples")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: height)
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard samples.count > 1 else { return [] }

        let maxDistance = max(samples.last?.distanceMeters ?? 0, 1)
        let minAltitude = samples.map(\.altitudeMeters).min() ?? 0
        let maxAltitude = samples.map(\.altitudeMeters).max() ?? 0
        let altitudeRange = max(maxAltitude - minAltitude, 1)

        return samples.map { sample in
            let x = (sample.distanceMeters / maxDistance) * size.width
            let normalized = (sample.altitudeMeters - minAltitude) / altitudeRange
            let y = size.height - (normalized * size.height)
            return CGPoint(x: x, y: y)
        }
    }

    private var topAltitudeLabel: String {
        let maxAltitude = samples.map(\.altitudeMeters).max() ?? 0
        return "\(Int(maxAltitude.rounded())) m"
    }

    private var bottomAltitudeLabel: String {
        let minAltitude = samples.map(\.altitudeMeters).min() ?? 0
        return "\(Int(minAltitude.rounded())) m"
    }

    private var distanceLabel: String {
        let distanceMeters = samples.last?.distanceMeters ?? 0
        return String(format: "%.1f km", max(0, distanceMeters) / 1000)
    }
}

struct TrailMindLiveActivityExtension: Widget {
    let kind: String = "TrailMindLiveActivityExtension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                TrailMindLiveActivityExtensionEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                TrailMindLiveActivityExtensionEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Trail Snapshot")
        .description("Shows live hiking duration, distance, altitude, and profile.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    TrailMindLiveActivityExtension()
} timeline: {
    SimpleEntry(date: .now, mirror: .preview)
}

struct SharedMirrorState: Codable {
    struct AltitudeSample: Codable, Hashable {
        let distanceMeters: Double
        let altitudeMeters: Double
    }

    let startedAt: Date
    let elapsedSeconds: Int
    let distanceMeters: Double
    let currentAltitudeMeters: Double
    let elevationGainMeters: Double
    let altitudeSamples: [AltitudeSample]
    let isTracking: Bool
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case startedAt
        case elapsedSeconds
        case distanceMeters
        case currentAltitudeMeters
        case elevationGainMeters
        case altitudeSamples
        case isTracking
        case updatedAt
    }

    init(
        startedAt: Date,
        elapsedSeconds: Int,
        distanceMeters: Double,
        currentAltitudeMeters: Double,
        elevationGainMeters: Double,
        altitudeSamples: [AltitudeSample],
        isTracking: Bool,
        updatedAt: Date?
    ) {
        self.startedAt = startedAt
        self.elapsedSeconds = elapsedSeconds
        self.distanceMeters = distanceMeters
        self.currentAltitudeMeters = currentAltitudeMeters
        self.elevationGainMeters = elevationGainMeters
        self.altitudeSamples = altitudeSamples
        self.isTracking = isTracking
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        elapsedSeconds = try container.decodeIfPresent(Int.self, forKey: .elapsedSeconds) ?? 0
        distanceMeters = try container.decodeIfPresent(Double.self, forKey: .distanceMeters) ?? 0
        currentAltitudeMeters = try container.decodeIfPresent(Double.self, forKey: .currentAltitudeMeters) ?? 0
        elevationGainMeters = try container.decodeIfPresent(Double.self, forKey: .elevationGainMeters) ?? 0
        altitudeSamples = try container.decodeIfPresent([AltitudeSample].self, forKey: .altitudeSamples) ?? []
        isTracking = try container.decodeIfPresent(Bool.self, forKey: .isTracking) ?? false
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(elapsedSeconds, forKey: .elapsedSeconds)
        try container.encode(distanceMeters, forKey: .distanceMeters)
        try container.encode(currentAltitudeMeters, forKey: .currentAltitudeMeters)
        try container.encode(elevationGainMeters, forKey: .elevationGainMeters)
        try container.encode(altitudeSamples, forKey: .altitudeSamples)
        try container.encode(isTracking, forKey: .isTracking)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }

    static let preview = SharedMirrorState(
        startedAt: .now.addingTimeInterval(-5470),
        elapsedSeconds: 5470,
        distanceMeters: 8340,
        currentAltitudeMeters: 912,
        elevationGainMeters: 486,
        altitudeSamples: previewSamples(),
        isTracking: true,
        updatedAt: .now
    )

    static func previewSamples() -> [AltitudeSample] {
        (0...48).map { index in
            let distance = Double(index) * 180
            let base = 550 + sin(Double(index) / 6) * 120
            let climb = Double(index) * 6.4
            let altitude = base + climb
            return AltitudeSample(distanceMeters: distance, altitudeMeters: altitude)
        }
    }
}

enum SharedMirrorStore {
    static let groupID = "group.com.david.TrailMind"
    static let stateKey = "live_activity_mirror_state"
    static let stateFileName = "live_activity_mirror_state.json"

    static func load() -> SharedMirrorState? {
        if let fileURL = fileURL(),
           let data = try? Data(contentsOf: fileURL),
           let state = try? JSONDecoder().decode(SharedMirrorState.self, from: data) {
            return state
        }

        guard let defaults = UserDefaults(suiteName: groupID) else { return nil }
        guard let data = defaults.data(forKey: stateKey) else { return nil }
        return try? JSONDecoder().decode(SharedMirrorState.self, from: data)
    }

    private static func fileURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupID
        ) else {
            return nil
        }
        return containerURL.appendingPathComponent(stateFileName)
    }
}
