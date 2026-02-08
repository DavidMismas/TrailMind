import Foundation
import Combine

final class UserProfileStore: ObservableObject {
    @Published private(set) var profile: UserProfile?

    private let key = "trailmind.user_profile"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.profile = Self.loadProfile(from: defaults, key: key)
    }

    var needsOnboarding: Bool {
        profile == nil
    }

    func save(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
        self.profile = profile
    }

    private static func loadProfile(from defaults: UserDefaults, key: String) -> UserProfile? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }
}
