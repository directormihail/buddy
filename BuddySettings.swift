import AVFoundation
import SwiftUI
import UIKit

/// Short vs longer replies — drives `max_tokens` and system prompt (Settings Part 7).
enum BuddyResponseLength: String, CaseIterable, Identifiable {
    case short
    case detailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .short: return "Short"
        case .detailed: return "Detailed"
        }
    }

    var subtitle: String {
        switch self {
        case .short: return "Quick voice replies"
        case .detailed: return "More explanation when helpful"
        }
    }

    var maxTokens: Int {
        switch self {
        case .short: return 120
        case .detailed: return 280
        }
    }
}

/// Lightweight haptics for orb / voice flows (respects user toggle).
enum BuddyHaptics {
    static func orbPressed(enabled: Bool) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func orbReleased(enabled: Bool) {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func softAck(enabled: Bool) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

enum BuddyVoiceCatalog {
    /// Voices matching the user’s preferred language first, then English.
    static var selectableVoices: [AVSpeechSynthesisVoice] {
        let all = AVSpeechSynthesisVoice.speechVoices()
        let preferred = Locale.preferredLanguages.first ?? "en-US"
        let shortLang = preferred.split(separator: "-").first.map(String.init) ?? "en"

        let primary = all.filter { $0.language == preferred || $0.language.hasPrefix(preferred) }
        let secondary = all.filter { $0.language.hasPrefix(shortLang + "-") || $0.language == shortLang }
        let english = all.filter { $0.language.hasPrefix("en") }

        let merged = primary.isEmpty ? (secondary.isEmpty ? english : secondary) : primary
        let dedup = Dictionary(grouping: merged, by: \.identifier).compactMap(\.value.first)
        return dedup.sorted {
            if $0.name != $1.name { return $0.name < $1.name }
            return $0.identifier < $1.identifier
        }
    }
}

@MainActor
final class BuddySettingsStore: ObservableObject {
    private enum Keys {
        static let displayName = "buddy.settings.displayName"
        static let responseLength = "buddy.settings.responseLength"
        static let voiceIdentifier = "buddy.settings.voiceIdentifier"
        static let hapticsEnabled = "buddy.settings.hapticsEnabled"
    }

    private let defaults = UserDefaults.standard

    @Published var displayName: String {
        didSet { defaults.set(displayName, forKey: Keys.displayName) }
    }

    @Published var responseLength: BuddyResponseLength {
        didSet { defaults.set(responseLength.rawValue, forKey: Keys.responseLength) }
    }

    /// Empty string means system default voice.
    @Published var selectedVoiceIdentifier: String {
        didSet { defaults.set(selectedVoiceIdentifier, forKey: Keys.voiceIdentifier) }
    }

    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }

    init() {
        displayName = defaults.string(forKey: Keys.displayName) ?? ""
        if let raw = defaults.string(forKey: Keys.responseLength),
           let len = BuddyResponseLength(rawValue: raw)
        {
            responseLength = len
        } else {
            responseLength = .short
        }
        selectedVoiceIdentifier = defaults.string(forKey: Keys.voiceIdentifier) ?? ""
        if defaults.object(forKey: Keys.hapticsEnabled) == nil {
            hapticsEnabled = true
        } else {
            hapticsEnabled = defaults.bool(forKey: Keys.hapticsEnabled)
        }
    }

    /// First name for prompts and greetings; falls back to “friend”.
    var resolvedDisplayName: String {
        let t = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "friend" : t
    }

    var voiceMenuLabel: String {
        if selectedVoiceIdentifier.isEmpty { return "System default" }
        if let v = AVSpeechSynthesisVoice(identifier: selectedVoiceIdentifier) {
            return v.name
        }
        return "System default"
    }
}
