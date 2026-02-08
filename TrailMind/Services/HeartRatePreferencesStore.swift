import Foundation

final class HeartRatePreferencesStore {
    private enum Keys {
        static let preferBLE = "trailmind.hr.preferBLE"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var preferBLE: Bool {
        get { defaults.bool(forKey: Keys.preferBLE) }
        set { defaults.set(newValue, forKey: Keys.preferBLE) }
    }
}
