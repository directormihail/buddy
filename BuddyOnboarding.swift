import Foundation

enum BuddyOnboarding {
    /// Same key used by `@AppStorage` in `ContentView` so replay stays in sync.
    static let storageKey = "buddy.onboarding.completed"

    static var isComplete: Bool {
        get { UserDefaults.standard.bool(forKey: storageKey) }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }
}

/// Per-page mascot acting on onboarding: arm waves, explaining tilt, bob — timed with `TimelineView`.
enum BuddyOnboardingMascotPose: Int, CaseIterable {
    case welcome
    case howItWorks
    case privacy

    init(pageIndex: Int) {
        self = Self(rawValue: pageIndex) ?? .welcome
    }

    var primaryEmoji: String {
        switch self {
        case .welcome: return "😊"
        case .howItWorks: return "🎙️"
        case .privacy: return "🔒"
        }
    }

    var secondaryEmoji: String {
        switch self {
        case .welcome: return "✨"
        case .howItWorks: return "💬"
        case .privacy: return "🛡️"
        }
    }

    func leftArmExtraDegrees(at t: TimeInterval) -> Double {
        switch self {
        case .welcome:
            return sin(t * 2.8) * 16
        case .howItWorks:
            return 20 + sin(t * 2.35) * 12
        case .privacy:
            return -8 + sin(t * 1.7) * 5
        }
    }

    func rightArmExtraDegrees(at t: TimeInterval) -> Double {
        switch self {
        case .welcome:
            return sin(t * 2.8 + .pi) * 16
        case .howItWorks:
            return sin(t * 2.8) * 10
        case .privacy:
            return 8 + sin(t * 1.7) * -5
        }
    }

    func bodyTiltDegrees(at t: TimeInterval) -> Double {
        switch self {
        case .welcome:
            return sin(t * 1.15) * 2.8
        case .howItWorks:
            return 3 + sin(t * 1.4) * 4.5
        case .privacy:
            return sin(t * 0.95) * 2
        }
    }

    func extraBobPoints(at t: TimeInterval) -> CGFloat {
        switch self {
        case .welcome:
            return CGFloat(sin(t * 2.25) * 6)
        case .howItWorks:
            return CGFloat(sin(t * 2.5) * 4)
        case .privacy:
            return CGFloat(sin(t * 1.05) * 3)
        }
    }
}
