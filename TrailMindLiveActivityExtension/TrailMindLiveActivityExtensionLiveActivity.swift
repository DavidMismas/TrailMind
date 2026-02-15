//
//  TrailMindLiveActivityExtensionLiveActivity.swift
//  TrailMindLiveActivityExtension
//
//  Created by David Mišmaš on 8. 2. 26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TrailMindHikeLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var distanceMeters: Double
        var currentAltitudeMeters: Double
        var elevationGainMeters: Double
    }

    var startedAt: Date
}

struct TrailMindLiveActivityExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrailMindHikeLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Hike In Progress", systemImage: "figure.hiking")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.green.opacity(0.2), in: Capsule())
                }

                HStack(spacing: 16) {
                    metricView(
                        title: "Duration",
                        value: Text(context.attributes.startedAt, style: .timer),
                        isTrailing: false
                    )
                    metricView(
                        title: "Distance",
                        value: Text(distanceText(context.state.distanceMeters)),
                        isTrailing: true
                    )
                }

                HStack(spacing: 16) {
                    metricView(
                        title: "Altitude",
                        value: Text(altitudeText(context.state.currentAltitudeMeters)),
                        isTrailing: false
                    )
                    metricView(
                        title: "Gain",
                        value: Text(altitudeText(context.state.elevationGainMeters)),
                        isTrailing: true
                    )
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .activityBackgroundTint(Color.black.opacity(0.2))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.attributes.startedAt, style: .timer)
                            .monospacedDigit()
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Distance")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(distanceText(context.state.distanceMeters))
                            .monospacedDigit()
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "mountain.2")
                        Text("Alt \(altitudeText(context.state.currentAltitudeMeters))")
                            .font(.subheadline)
                        Spacer()
                        Text("Gain \(altitudeText(context.state.elevationGainMeters))")
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.hiking")
            } compactTrailing: {
                Text(shortDistanceText(context.state.distanceMeters))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "figure.hiking")
            }
            .keylineTint(.green)
        }
    }

    private func metricView(title: String, value: Text, isTrailing: Bool) -> some View {
        VStack(alignment: isTrailing ? .trailing : .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            value
                .monospacedDigit()
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: isTrailing ? .trailing : .leading)
    }

    private func distanceText(_ meters: Double) -> String {
        String(format: "%.2f km", max(0, meters) / 1000)
    }

    private func shortDistanceText(_ meters: Double) -> String {
        String(format: "%.1fkm", max(0, meters) / 1000)
    }

    private func altitudeText(_ meters: Double) -> String {
        "\(Int(meters.rounded())) m"
    }
}

#Preview("Notification", as: .content, using: TrailMindHikeLiveActivityAttributes(startedAt: .now.addingTimeInterval(-1870))) {
    TrailMindLiveActivityExtensionLiveActivity()
} contentStates: {
    TrailMindHikeLiveActivityAttributes.ContentState(
        elapsedSeconds: 1870,
        distanceMeters: 4230,
        currentAltitudeMeters: 912,
        elevationGainMeters: 486
    )
}
