import SwiftUI

/// Merge Apple on-device STT with Whisper and reject single-token noise before it reaches the chat UI / API.
enum TranscriptQuality {
    /// Prefer Whisper whenever it returns text; keep Apple only when Whisper looks like noise but Apple does not.
    static func mergeAppleAndWhisper(apple: String, whisper: String) -> String {
        let a = apple.trimmingCharacters(in: .whitespacesAndNewlines)
        let w = whisper.trimmingCharacters(in: .whitespacesAndNewlines)
        if !w.isEmpty {
            if isLikelyNoiseOnly(w), !a.isEmpty, !isLikelyNoiseOnly(a) { return a }
            return w
        }
        return a
    }

    /// Empty or noise-only phrases must never create a user bubble or OpenAI request.
    static func shouldSendToChat(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        return !isLikelyNoiseOnly(t)
    }

    /// Single-token junk from silence / bad STT (matches strings that were leaking into blue bubbles as “you”).
    static func isLikelyNoiseOnly(_ text: String) -> Bool {
        let t = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return true }
        let words = t.split(whereSeparator: { $0.isWhitespace })
        guard words.count == 1 else { return false }
        let noise: Set<String> = [
            "you", "your", "you're", "uh", "um", "ah", "oh", "er", "hm", "hmm"
        ]
        return noise.contains(String(words[0]))
    }
}

/// Drives mascot animations and the voice UI (same phases as `ChatView`).
enum BuddyInteractionPhase: Equatable {
    case idle
    case listening
    case processing
    case speaking
}

enum Constants {
    static let apiKey = "PASTE_YOUR_ANTHROPIC_API_KEY_HERE"
    static let anthropicURL = URL(string: "https://api.anthropic.com/v1/messages")!
    static let model = "claude-sonnet-4-20250514"

    /// OpenAI Chat Completions (streaming). Key comes from `.env` → `OpenAISecrets.plist` at build time.
    static let openAIChatURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    static let openAIModel = "gpt-4o"

    /// Fallback speech-to-text when Apple’s on-device recognizer returns nothing (needs network + same API key).
    static let openAITranscriptionsURL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    static let openAIWhisperModel = "whisper-1"

    static let maxHistoryMessages = 20

    static func systemPrompt(displayName: String, length: BuddyResponseLength) -> String {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "friend" : displayName
        switch length {
        case .short:
            return """
            You are Buddy, a friendly robot talking with \(name). Be warm and brief.

            Rules:
            - Answer in at most 2–3 short sentences (under ~70 words). No long lectures.
            - Match what the user just said; acknowledge their topic before adding your bit.
            - Simple words, kid-friendly. Plain text only—no emoji or decorative symbols; replies are read aloud.
            - Never violence, scary, or grown-up topics. If unsure, ask a simple clarifying question.
            """
        case .detailed:
            return """
            You are Buddy, a friendly robot talking with \(name). Be warm and clear.

            Rules:
            - When the topic needs it, answer in about 4–7 sentences (under ~180 words). Stay organized; no endless essays.
            - Match what the user just said; acknowledge their topic before adding your bit.
            - Simple words, kid-friendly. Plain text only—no emoji or decorative symbols; replies are read aloud.
            - Never violence, scary, or grown-up topics. If unsure, ask a simple clarifying question.
            """
        }
    }
}

enum BuddyColors {
    static let softPurple = Color(hex: 0x8B5CF6)
    static let lightBlue = Color(hex: 0x60A5FA)
    static let warmYellow = Color(hex: 0xFCD34D)
    static let kidBubble = Color(hex: 0x60A5FA)
    static let buddyBubble = Color(hex: 0x8B5CF6)

    /// Transcript drawer: Buddy messages (left, light bubble).
    static let transcriptBuddyFill = Color(hex: 0xF3F4F6)
    static let transcriptBuddyText = Color(hex: 0x111827)
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - SwiftUI onChange (iOS 16 + 17 SDK without deprecation noise)

extension View {
    /// Forwards to the iOS 17 two-parameter `onChange` when available; otherwise the iOS 16 API.
    func buddyOnChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        modifier(BuddyOnChangeCompatModifier(value: value, action: action))
    }
}

private struct BuddyOnChangeCompatModifier<V: Equatable>: ViewModifier {
    let value: V
    let action: (V) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            content.onChange(of: value, perform: action)
        }
    }
}
