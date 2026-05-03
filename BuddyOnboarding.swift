import Foundation

enum BuddyOnboarding {
    /// Same key used by `@AppStorage` in `ContentView` so replay stays in sync.
    static let storageKey = "buddy.onboarding.completed"

    static var isComplete: Bool {
        get { UserDefaults.standard.bool(forKey: storageKey) }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }
}
