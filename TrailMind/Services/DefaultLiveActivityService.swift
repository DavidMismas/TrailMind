import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

struct TrailMindHikeLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var distanceMeters: Double
    }

    var startedAt: Date
}

@MainActor
final class DefaultLiveActivityService: LiveActivityService {
    private enum SharedConfig {
        static let appGroupID = "group.com.david.TrailMind"
        static let stateKey = "live_activity_mirror_state"
        static let stateFileName = "live_activity_mirror_state.json"
    }

    private struct MirrorState: Codable {
        var startedAt: Date
        var elapsedSeconds: Int
        var distanceMeters: Double
        var currentAltitudeMeters: Double
        var elevationGainMeters: Double
        var altitudeSamples: [LiveAltitudeSample]
        var isTracking: Bool
        var updatedAt: Date
    }

#if canImport(ActivityKit)
    private var activityID: String?
#endif

#if canImport(WidgetKit)
    private var lastWidgetReloadAt: Date?
    private let widgetReloadInterval: TimeInterval = 20
#endif

    func start(
        startedAt: Date,
        elapsed: TimeInterval,
        distanceMeters: Double,
        currentAltitudeMeters: Double,
        elevationGainMeters: Double,
        altitudeSamples: [LiveAltitudeSample]
    ) {
        let state = makeState(elapsed: elapsed, distanceMeters: distanceMeters)
        saveMirror(
            MirrorState(
                startedAt: startedAt,
                elapsedSeconds: state.elapsedSeconds,
                distanceMeters: state.distanceMeters,
                currentAltitudeMeters: currentAltitudeMeters,
                elevationGainMeters: elevationGainMeters,
                altitudeSamples: altitudeSamples,
                isTracking: true,
                updatedAt: Date()
            )
        )
        reloadWidgetTimelines(force: true)

#if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = TrailMindHikeLiveActivityAttributes(startedAt: startedAt)
        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(120)
        )

        Task { [weak self] in
            guard let self else { return }
            await endExistingActivities()
            do {
                let activity = try Activity<TrailMindHikeLiveActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                activityID = activity.id
            } catch {
                activityID = nil
            }
        }
#endif
    }

    func update(
        startedAt: Date,
        elapsed: TimeInterval,
        distanceMeters: Double,
        currentAltitudeMeters: Double,
        elevationGainMeters: Double,
        altitudeSamples: [LiveAltitudeSample]
    ) {
        let state = makeState(elapsed: elapsed, distanceMeters: distanceMeters)
        saveMirror(
            MirrorState(
                startedAt: startedAt,
                elapsedSeconds: state.elapsedSeconds,
                distanceMeters: state.distanceMeters,
                currentAltitudeMeters: currentAltitudeMeters,
                elevationGainMeters: elevationGainMeters,
                altitudeSamples: altitudeSamples,
                isTracking: true,
                updatedAt: Date()
            )
        )
        reloadWidgetTimelines(force: false)

#if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(120)
        )
        Task { [weak self] in
            guard let self else { return }
            guard let activity = currentActivity() else { return }
            await activity.update(content)
        }
#endif
    }

    func stop(
        startedAt: Date,
        elapsed: TimeInterval,
        distanceMeters: Double,
        currentAltitudeMeters: Double,
        elevationGainMeters: Double,
        altitudeSamples: [LiveAltitudeSample]
    ) {
        let state = makeState(elapsed: elapsed, distanceMeters: distanceMeters)
        saveMirror(
            MirrorState(
                startedAt: startedAt,
                elapsedSeconds: state.elapsedSeconds,
                distanceMeters: state.distanceMeters,
                currentAltitudeMeters: currentAltitudeMeters,
                elevationGainMeters: elevationGainMeters,
                altitudeSamples: altitudeSamples,
                isTracking: false,
                updatedAt: Date()
            )
        )
        reloadWidgetTimelines(force: true)

#if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else {
            clearMirror()
            return
        }

        let content = ActivityContent(state: state, staleDate: Date())
        Task { [weak self] in
            guard let self else { return }
            if let activity = currentActivity() {
                await activity.end(content, dismissalPolicy: .immediate)
            }
            activityID = nil
            clearMirror()
        }
#else
        clearMirror()
#endif
    }

    private func makeState(elapsed: TimeInterval, distanceMeters: Double) -> TrailMindHikeLiveActivityAttributes.ContentState {
        TrailMindHikeLiveActivityAttributes.ContentState(
            elapsedSeconds: max(0, Int(elapsed.rounded())),
            distanceMeters: max(0, distanceMeters)
        )
    }

    private func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: SharedConfig.appGroupID)
    }

    private func mirrorFileURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedConfig.appGroupID
        ) else {
            return nil
        }
        return containerURL.appendingPathComponent(SharedConfig.stateFileName)
    }

    private func saveMirror(_ state: MirrorState) {
        guard let encoded = try? JSONEncoder().encode(state) else { return }

        if let defaults = sharedDefaults() {
            defaults.set(encoded, forKey: SharedConfig.stateKey)
            defaults.synchronize()
        }

        if let fileURL = mirrorFileURL() {
            try? encoded.write(to: fileURL, options: .atomic)
        }
    }

    private func clearMirror() {
        sharedDefaults()?.removeObject(forKey: SharedConfig.stateKey)
        sharedDefaults()?.synchronize()

        if let fileURL = mirrorFileURL() {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func reloadWidgetTimelines(force: Bool) {
#if canImport(WidgetKit)
        let now = Date()
        if !force, let lastWidgetReloadAt, now.timeIntervalSince(lastWidgetReloadAt) < widgetReloadInterval {
            return
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "TrailMindLiveActivityExtension")
        WidgetCenter.shared.reloadAllTimelines()
        lastWidgetReloadAt = now
#endif
    }

#if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private func currentActivity() -> Activity<TrailMindHikeLiveActivityAttributes>? {
        if let activityID, let exact = Activity<TrailMindHikeLiveActivityAttributes>.activities.first(where: { $0.id == activityID }) {
            return exact
        }
        return Activity<TrailMindHikeLiveActivityAttributes>.activities.first
    }

    @available(iOS 16.2, *)
    private func endExistingActivities() async {
        for activity in Activity<TrailMindHikeLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
#endif
}
