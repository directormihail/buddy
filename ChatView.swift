import AVFoundation
import Speech
import SwiftUI

private let finishingTranscriptionStatus = "Finishing transcription…"

/// Runs Whisper on the **same** WAV file captured for this utterance (passed synchronously — avoids races with the next recording).
private func resolveSpokenText(appleRaw: String, utteranceWAV: URL?, openAI: OpenAIService) async -> String {
    let apple = appleRaw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let utteranceWAV else { return apple }
    defer { try? FileManager.default.removeItem(at: utteranceWAV) }
    do {
        let whisper = try await openAI.transcribeSpeechWAV(fileURL: utteranceWAV)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return TranscriptQuality.mergeAppleAndWhisper(apple: apple, whisper: whisper)
    } catch {
        return apple
    }
}

struct ChatView: View {
    @EnvironmentObject private var settings: BuddySettingsStore
    @State private var statusText = "Press and hold the orb to talk with Buddy"
    @State private var phase: BuddyInteractionPhase = .idle
    @State private var liveTranscript = ""
    @State private var shortMemory: [Message] = []
    /// Full last model reply for Part 3 (TTS); updated after streaming completes.
    @State private var lastAssistantReplyForTTS = ""
    @StateObject private var voice = VoiceAssistantController()
    /// Prevents duplicate DragGesture `onChanged` from starting multiple recognition sessions.
    @State private var orbHoldStarted = false
    @State private var showConversationLog = false
    /// Rotating / context-aware suggestion chips (filled when returning to idle).
    @State private var displayedPromptChips: [String] = PromptChipLibrary.pickHints([])
    @State private var showSettings = false

    private let openAI = OpenAIService()

    var body: some View {
        ZStack {
            PremiumBackground()

            VStack(spacing: 14) {
                ZStack(alignment: .top) {
                    Text("Buddy")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: 0x25436B), Color(hex: 0x4A7FD9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(maxWidth: .infinity)

                    HStack {
                        Spacer()
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x315F92).opacity(0.88))
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.88))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.07), radius: 8, y: 3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Settings")
                    }
                }

                BuddyRobotView(interactionPhase: phase, speakingWordPulse: voice.ttsWordPulse)
                    .frame(height: 430)
                    .padding(.top, 4)

                if !liveTranscript.isEmpty, phase == .listening || (phase == .processing && statusText == finishingTranscriptionStatus) {
                    Text(liveTranscript)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: 0x315F92).opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 8)
                }

                QuickIdeasStrip(ideas: displayedPromptChips, isVisible: phase == .idle) { idea in
                    submitPromptChip(idea)
                }

                if !shortMemory.isEmpty {
                    Button {
                        showConversationLog = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "text.bubble.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Read chat")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text("(\(shortMemory.count))")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: 0x315F92).opacity(0.75))
                        }
                        .foregroundStyle(Color(hex: 0x315F92))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.92))
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open conversation transcript")
                }

                Text(orbInstructionText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: 0x47607D))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)

                VoiceOrbButton(interactionPhase: phase)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                guard phase != .processing else { return }
                                guard !orbHoldStarted else { return }
                                if phase == .idle || phase == .speaking {
                                    orbHoldStarted = true
                                    BuddyHaptics.orbPressed(enabled: settings.hapticsEnabled)
                                    startVoiceCapture()
                                }
                            }
                            .onEnded { _ in
                                orbHoldStarted = false
                                guard voice.isListening else { return }
                                BuddyHaptics.orbReleased(enabled: settings.hapticsEnabled)
                                // Switch immediately so transcription + Whisper run visibly “in the background” after release.
                                phase = .processing
                                statusText = finishingTranscriptionStatus
                                voice.stopListening()
                            }
                    )
                    .padding(.bottom, 18)

                #if targetEnvironment(simulator)
                Text("Tip: speech recognition is most reliable on a real iPhone.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: 0x47607D).opacity(0.65))
                    .multilineTextAlignment(.center)
                #endif
            }
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $showConversationLog) {
            ConversationLogSheet(messages: shortMemory, isPresented: $showConversationLog)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings)
                .environmentObject(settings)
        }
        .onAppear {
            voice.prepare()
            let intro = personalizedIntroLine()
            statusText = intro
            phase = .speaking
            speakBuddy(intro) {
                if phase == .speaking { phase = .idle }
            }
        }
        .onChange(of: phase) { newPhase in
            if newPhase == .idle {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    displayedPromptChips = PromptChipLibrary.pickHints(shortMemory)
                }
            }
        }
    }

    /// Sends the chip text straight to the model (no mic), interrupting any intro TTS or listening.
    private func submitPromptChip(_ text: String) {
        voice.cancelVoiceSessionForTextChip()
        liveTranscript = ""
        orbHoldStarted = false
        Task { await askBuddy(with: text) }
    }

    /// Under the orb: live status while processing (transcription → streamed reply).
    private var orbInstructionText: String {
        switch phase {
        case .idle: return "Hold to speak"
        case .listening: return "Listening…"
        case .processing: return statusText
        case .speaking: return "Buddy is speaking"
        }
    }

    private func startVoiceCapture() {
        liveTranscript = ""
        statusText = "Getting microphone ready…"
        Task { @MainActor in
            let didStart = await voice.startListening(
                onPartial: { partial in
                    liveTranscript = partial
                    statusText = partial.isEmpty ? "Listening…" : partial
                },
                onFinal: { transcript, utteranceWAV in
                    Task {
                        let merged = await resolveSpokenText(
                            appleRaw: transcript,
                            utteranceWAV: utteranceWAV,
                            openAI: openAI
                        )
                        var text = merged.trimmingCharacters(in: .whitespacesAndNewlines)

                        let partialFallback = await MainActor.run { voice.bestPartialTranscriptThisSession }
                        if !TranscriptQuality.shouldSendToChat(text),
                           TranscriptQuality.shouldSendToChat(partialFallback)
                        {
                            text = partialFallback
                        }

                        await MainActor.run {
                            guard TranscriptQuality.shouldSendToChat(text) else {
                                liveTranscript = ""
                                let spoken: String
                                let shown: String
                                if !OpenAIService.isAPIKeyConfigured {
                                    shown = "OpenAI API key missing — add OPENAI_API_KEY (scheme env or .env), then Clean Build."
                                    spoken = "Add an OpenAI API key in Xcode so Buddy can transcribe your voice."
                                } else {
                                    shown = "I did not catch that. Hold the orb a bit longer and speak clearly."
                                    spoken = shown
                                }
                                statusText = shown
                                phase = .speaking
                                speakBuddy(spoken) {
                                    if phase == .speaking { phase = .idle }
                                }
                                return
                            }
                            Task { await askBuddy(with: text) }
                        }
                    }
                }
            )
            await MainActor.run {
                if didStart {
                    phase = .listening
                    if liveTranscript.isEmpty {
                        statusText = "Listening…"
                    }
                } else {
                    phase = .idle
                    statusText = voice.voicePermissionHint
                        ?? "Microphone or speech recognition isn’t available. Enable both for Buddy in Settings → Privacy."
                }
            }
        }
    }

    private func askBuddy(with kidText: String) async {
        let trimmed = kidText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard TranscriptQuality.shouldSendToChat(trimmed) else { return }

        await MainActor.run {
            phase = .processing
            statusText = "Thinking…"
            liveTranscript = ""
            shortMemory.append(.init(role: .user, text: trimmed))
            if shortMemory.count > Constants.maxHistoryMessages {
                shortMemory = Array(shortMemory.suffix(Constants.maxHistoryMessages))
            }
        }

        let (messagesSnapshot, displayName, responseLength) = await MainActor.run {
            (shortMemory, settings.resolvedDisplayName, settings.responseLength)
        }

        do {
            let reply = try await openAI.streamCompletion(
                messages: messagesSnapshot,
                displayName: displayName,
                responseLength: responseLength
            ) { accumulated in
                statusText = accumulated
            }
            await MainActor.run {
                lastAssistantReplyForTTS = reply
                statusText = reply
                shortMemory.append(.init(role: .buddy, text: reply))
                if shortMemory.count > Constants.maxHistoryMessages {
                    shortMemory = Array(shortMemory.suffix(Constants.maxHistoryMessages))
                }
                phase = .speaking
                speakBuddy(reply) {
                    if phase == .speaking { phase = .idle }
                }
            }
        } catch let openAIError as OpenAIServiceError {
            await MainActor.run {
                let fallback = openAIError.localizedDescription
                statusText = fallback
                lastAssistantReplyForTTS = ""
                phase = .speaking
                speakBuddy(fallback) {
                    if phase == .speaking { phase = .idle }
                }
            }
        } catch {
            await MainActor.run {
                let fallback = "Oops, my circuits got confused. Can we try again?"
                statusText = fallback
                lastAssistantReplyForTTS = ""
                phase = .speaking
                speakBuddy(fallback) {
                    if phase == .speaking { phase = .idle }
                }
            }
        }
    }

    private func personalizedIntroLine() -> String {
        let raw = settings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return "Hi friend! I am Buddy. Hold the orb and talk to me!"
        }
        return "Hi \(raw)! I am Buddy. Hold the orb and talk to me!"
    }

    private func speakBuddy(_ text: String, onFinish: (() -> Void)? = nil) {
        let trimmed = settings.selectedVoiceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        voice.speak(text, voiceIdentifier: trimmed.isEmpty ? nil : trimmed, onFinish: onFinish)
    }
}

private struct ConversationLogSheet: View {
    let messages: [Message]
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(messages) { message in
                            ChatBubble(message: message, onShowTimestamp: nil)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Color(hex: 0xF8FAFC))
                .onAppear {
                    scrollToLatest(proxy: proxy)
                }
                .onChange(of: messages.count) { _ in
                    scrollToLatest(proxy: proxy)
                }
                .onChange(of: messages.last?.id) { _ in
                    scrollToLatest(proxy: proxy)
                }
            }
            .navigationTitle("Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private func scrollToLatest(proxy: ScrollViewProxy) {
        guard let last = messages.last else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.28)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

private struct QuickIdeasStrip: View {
    let ideas: [String]
    var isVisible: Bool = true
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ideas, id: \.self) { idea in
                    Button {
                        onTap(idea)
                    } label: {
                        Text(idea)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: 0x315F92))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.78))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Sends this message as text, without using the microphone")
                }
            }
            .padding(.horizontal, 2)
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.94, anchor: .bottom)
        .offset(y: isVisible ? 0 : 14)
        .animation(.spring(response: 0.4, dampingFraction: 0.84), value: isVisible)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
    }
}

/// Time-of-day buckets, topic-aware follow-ups from recent chat, and random variety for prompt chips.
private enum PromptChipLibrary {
    private static let universal: [String] = [
        "Tell me a short funny story",
        "Teach me a cool animal fact",
        "Play a tiny guessing game",
        "Give me a silly would-you-rather question",
        "What’s a mind-blowing science fact for kids?",
        "Make up a nickname for me and use it once",
        "Pretend we’re on a spaceship — what do you see?",
        "Give me a compliment wrapped in a joke",
        "What’s a tiny habit that makes the day better?",
        "Tell me a riddle (don’t reveal the answer yet)"
    ]

    private static let morning: [String] = [
        "Good morning — give me a cheerful boost",
        "What’s a fun way to start the day?",
        "Tell me a sunny one-liner joke"
    ]

    private static let afternoon: [String] = [
        "Quick brain break — surprise me",
        "Quiz me with 3 easy trivia questions",
        "Teach me something weird about space"
    ]

    private static let evening: [String] = [
        "Wind-down: one calm fun fact",
        "Tell me a cozy micro-story",
        "What’s something kind I could do today?"
    ]

    private static let night: [String] = [
        "One short cozy story before I relax",
        "Tell me a peaceful nature fact",
        "Suggest a calm breathing game"
    ]

    private static let humorExtras: [String] = [
        "Another joke, but make it extra goofy",
        "Roast me in the nicest possible way",
        "Funny sound-effect story — keep it short"
    ]

    private static let storyExtras: [String] = [
        "Another tiny story with a twist ending",
        "Story where I’m the hero",
        "Story told only as dialogue"
    ]

    private static let natureExtras: [String] = [
        "More animal facts — surprise me",
        "Underwater creature spotlight",
        "Weird plant superpowers"
    ]

    private static let gameExtras: [String] = [
        "New guessing game — easy mode",
        "20 questions: you think of something",
        "Rhyme-time challenge — keep it short"
    ]

    private static let learningExtras: [String] = [
        "Explain something tricky like I’m 8",
        "Memory trick for studying",
        "Turn one topic into a silly song title"
    ]

    static func pickHints(_ messages: [Message]) -> [String] {
        let hour = Calendar.current.component(.hour, from: Date())
        var pool: [String] = universal

        switch hour {
        case 5 ..< 12:
            pool.append(contentsOf: morning)
        case 12 ..< 17:
            pool.append(contentsOf: afternoon)
        case 17 ..< 22:
            pool.append(contentsOf: evening)
        default:
            pool.append(contentsOf: night)
        }

        let recentUser = messages.suffix(10).filter { $0.role == .user }.map(\.text)
        let blob = recentUser.joined(separator: " ").lowercased()

        if blob.contains("joke") || blob.contains("funny") || blob.contains("laugh") || blob.contains("silly") {
            pool.append(contentsOf: humorExtras)
        }
        if blob.contains("story") || blob.contains("tale") || blob.contains("tell me about") {
            pool.append(contentsOf: storyExtras)
        }
        if blob.contains("animal") || blob.contains("dino") || blob.contains("ocean") || blob.contains("bug") {
            pool.append(contentsOf: natureExtras)
        }
        if blob.contains("game") || blob.contains("guess") || blob.contains("riddle") || blob.contains("quiz") {
            pool.append(contentsOf: gameExtras)
        }
        if blob.contains("homework") || blob.contains("school") || blob.contains("math") || blob.contains("learn") {
            pool.append(contentsOf: learningExtras)
        }

        var seen = Set<String>()
        var out: [String] = []
        for idea in pool.shuffled() where !seen.contains(idea) {
            seen.insert(idea)
            out.append(idea)
            if out.count == 3 { break }
        }
        var fallback = universal.shuffled().makeIterator()
        while out.count < 3, let next = fallback.next() {
            guard !seen.contains(next) else { continue }
            seen.insert(next)
            out.append(next)
        }
        return out
    }
}

private struct VoiceOrbButton: View {
    let phase: BuddyInteractionPhase

    init(interactionPhase: BuddyInteractionPhase) {
        phase = interactionPhase
    }

    private var isActive: Bool {
        phase != .idle
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: phase == .listening
                            ? [Color(hex: 0xFF8AD8), Color(hex: 0x68B9FF)]
                            : [Color(hex: 0x68B9FF), Color(hex: 0x4E8EFF)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)
                .overlay {
                    Image(systemName: phase == .processing ? "waveform.circle.fill" : "mic.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                }
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.45), lineWidth: 1.2)
                }
                .shadow(color: Color(hex: 0x5A9EFF).opacity(0.7), radius: phase == .listening ? 26 : 18, y: 9)
        }
        .scaleEffect(isActive ? 1.06 : 1.0)
        .animation(.easeInOut(duration: 0.35), value: phase)
    }
}

/// Writes 16‑bit mono PCM for OpenAI Whisper fallback when Apple speech recognition returns no text.
private enum BuddyWAVWriter {
    static func writeMonoPCM16LE(_ pcm: Data, sampleRate: UInt32) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("buddy-voice-\(UUID().uuidString).wav")
        let dataChunkSize = UInt32(pcm.count)
        let riffChunkSize = 36 + dataChunkSize
        var out = Data()
        out.append(contentsOf: "RIFF".utf8)
        out.append(contentsOf: Swift.withUnsafeBytes(of: riffChunkSize.littleEndian) { Data($0) })
        out.append(contentsOf: "WAVE".utf8)
        out.append(contentsOf: "fmt ".utf8)
        out.append(contentsOf: Swift.withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        out.append(contentsOf: Swift.withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        out.append(contentsOf: Swift.withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        out.append(contentsOf: Swift.withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        let byteRate = sampleRate * 2
        out.append(contentsOf: Swift.withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        out.append(contentsOf: Swift.withUnsafeBytes(of: UInt16(2).littleEndian) { Data($0) })
        out.append(contentsOf: Swift.withUnsafeBytes(of: UInt16(16).littleEndian) { Data($0) })
        out.append(contentsOf: "data".utf8)
        out.append(contentsOf: Swift.withUnsafeBytes(of: dataChunkSize.littleEndian) { Data($0) })
        out.append(pcm)
        try out.write(to: url, options: .atomic)
        return url
    }
}

/// Thread-safe tap copies for Whisper — safe to call from the audio render thread.
private final class BuddyPCMRecorder {
    private let lock = NSLock()
    private var data = Data()
    private var sampleRate: Double = 0

    func reset() {
        lock.lock()
        data.removeAll(keepingCapacity: false)
        sampleRate = 0
        lock.unlock()
    }

    func append(from buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        if sampleRate == 0 {
            sampleRate = buffer.format.sampleRate
        }
        let frames = Int(buffer.frameLength)
        guard frames > 0, let chData = buffer.floatChannelData else { return }
        let nCh = Int(buffer.format.channelCount)
        guard nCh >= 1 else { return }
        for i in 0 ..< frames {
            var sum: Float = 0
            if nCh == 1 {
                sum = chData[0][i]
            } else {
                for c in 0 ..< nCh {
                    sum += chData[c][i]
                }
                sum /= Float(nCh)
            }
            let clipped = max(-1, min(1, sum))
            let scaled = clipped * 32_767
            let sample = Int16(max(Float(Int16.min), min(Float(Int16.max), scaled)))
            var le = sample.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
    }

    /// Consumes buffered PCM and returns a WAV URL if there was enough audio (~≥120 ms).
    func takeWAVFile(minSeconds: Double = 0.06) -> URL? {
        lock.lock()
        let pcm = data
        let rate = sampleRate
        data.removeAll(keepingCapacity: false)
        sampleRate = 0
        lock.unlock()
        guard rate > 0, !pcm.isEmpty else { return nil }
        let duration = Double(pcm.count) / (rate * 2)
        guard duration >= minSeconds else { return nil }
        let sr = UInt32(rate.rounded())
        return try? BuddyWAVWriter.writeMonoPCM16LE(pcm, sampleRate: max(sr, 8000))
    }
}

@MainActor
final class VoiceAssistantController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isListening = false
    @Published private(set) var isSpeaking = false
    /// Increments for each TTS speech chunk (typically word-aligned) so the mascot can bounce on cadence.
    @Published private(set) var ttsWordPulse: Int = 0
    /// Set when `startListening` fails so the UI can show Settings-specific guidance.
    @Published private(set) var voicePermissionHint: String?

    private let audioEngine = AVAudioEngine()
    /// Prefer the user’s primary language so recognition matches how they speak.
    private let speechRecognizer: SFSpeechRecognizer? = {
        let preferred = Locale.preferredLanguages.first ?? "en-US"
        let locale = Locale(identifier: preferred)
        return SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let synthesizer = AVSpeechSynthesizer()
    private var onPartialText: ((String) -> Void)?
    private var onFinalText: ((String, URL?) -> Void)?
    private var onSpeechFinished: (() -> Void)?
    private var latestTranscript = ""
    private var hasDeliveredTranscript = false
    private var inflightListenTask: Task<Bool, Never>?
    /// Fires if no final callback arrives after `endAudio()` (don’t cancel the task immediately — that drops finals).
    private var finalizeTimeoutTask: Task<Void, Never>?
    /// True after `endAudio()` until we deliver a final transcript (distinguishes end-of-utterance errors from mid-stream noise).
    private var waitingForFinalAfterEndAudio = false
    /// Longest streaming partial this session — used when Apple’s final token is junk but earlier partials were good.
    private var longestPartialDuringSession = ""
    private let pcmRecorder = BuddyPCMRecorder()
    /// WAV built when recognition finishes — used if Apple STT text is empty (OpenAI Whisper).
    private var pendingTranscriptionWAV: URL?

    func prepare() {
        synthesizer.delegate = self
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    /// Stops TTS and any in-flight listening so a prompt chip can send text immediately (no mic path).
    func cancelVoiceSessionForTextChip() {
        finalizeTimeoutTask?.cancel()
        finalizeTimeoutTask = nil
        onSpeechFinished = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        ttsWordPulse = 0
        if isListening || recognitionRequest != nil {
            stopListening(deliverPartialTranscript: false)
        }
        discardPendingRecording()
    }

    func speak(_ text: String, voiceIdentifier: String? = nil, onFinish: (() -> Void)? = nil) {
        guard !text.isEmpty else {
            onFinish?()
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        onSpeechFinished = onFinish
        ttsWordPulse = 0
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.43
        utterance.pitchMultiplier = 1.12
        let voiceLang = Locale.preferredLanguages.first ?? "en-US"
        if let voiceIdentifier, !voiceIdentifier.isEmpty,
           let chosen = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        {
            utterance.voice = chosen
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: voiceLang) ?? AVSpeechSynthesisVoice(language: "en-US")
        }
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    /// Waits for Speech + Microphone permission if needed, then starts streaming recognition.
    func startListening(
        onPartial: @escaping (String) -> Void,
        onFinal: @escaping (String, URL?) -> Void
    ) async -> Bool {
        if let inflightListenTask {
            return await inflightListenTask.value
        }
        let task = Task { await self.performStartListening(onPartial: onPartial, onFinal: onFinal) }
        inflightListenTask = task
        let value = await task.value
        inflightListenTask = nil
        return value
    }

    private func performStartListening(
        onPartial: @escaping (String) -> Void,
        onFinal: @escaping (String, URL?) -> Void
    ) async -> Bool {
        voicePermissionHint = nil
        finalizeTimeoutTask?.cancel()
        finalizeTimeoutTask = nil

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            voicePermissionHint = "Speech recognition isn’t available on this device. Try a physical iPhone."
            return false
        }

        let speechOK = await ensureSpeechAuthorized()
        if !speechOK {
            switch SFSpeechRecognizer.authorizationStatus() {
            case .denied, .restricted:
                voicePermissionHint = "Turn on Speech Recognition: Settings → Privacy & Security → Speech Recognition → Buddy."
            default:
                voicePermissionHint = "Speech recognition permission was not granted."
            }
            return false
        }

        let micOK = await ensureMicrophoneAuthorized()
        if !micOK {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .denied:
                voicePermissionHint = "Turn on the microphone: Settings → Privacy & Security → Microphone → Buddy."
            default:
                voicePermissionHint = "Microphone permission was not granted."
            }
            return false
        }

        synthesizer.stopSpeaking(at: .immediate)
        if isSpeaking {
            isSpeaking = false
        }

        onPartialText = onPartial
        onFinalText = onFinal
        recognitionTask?.cancel()
        recognitionTask = nil
        waitingForFinalAfterEndAudio = false
        latestTranscript = ""
        hasDeliveredTranscript = false
        longestPartialDuringSession = ""
        pcmRecorder.reset()

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        audioEngine.reset()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .duckOthers, .allowBluetoothHFP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            do {
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers, .allowBluetoothHFP])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                voicePermissionHint = "Could not start audio session. Close other apps using the mic and try again."
                return false
            }
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Server-side recognition handles more accents/languages; on-device can fail silently on some locales.
        request.requiresOnDeviceRecognition = false
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        var format = inputNode.outputFormat(forBus: 0)
        if format.sampleRate == 0 || format.channelCount == 0 {
            try? session.setPreferredSampleRate(44_100)
            try? session.setActive(true)
            audioEngine.reset()
            format = inputNode.outputFormat(forBus: 0)
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.pcmRecorder.append(from: buffer)
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            cleanupAudioTracking()
            voicePermissionHint = "Could not start the microphone engine."
            return false
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.latestTranscript = text
                    if text.count > self.longestPartialDuringSession.count {
                        self.longestPartialDuringSession = text
                    }
                    self.onPartialText?(text)
                    if result.isFinal {
                        // While the user still holds the orb, keep buffering PCM. Finalizing consumes the recording
                        // and would truncate audio + send Whisper/OpenAI too early.
                        if self.isListening {
                            return
                        }
                        self.waitingForFinalAfterEndAudio = false
                        self.finalizeRecognitionSession(deliverLatest: text)
                    }
                }
                guard error != nil else { return }
                guard !self.hasDeliveredTranscript else { return }
                self.latestTranscript = self.latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                if self.waitingForFinalAfterEndAudio {
                    self.waitingForFinalAfterEndAudio = false
                    self.finalizeRecognitionSession(deliverLatest: self.latestTranscript)
                } else if self.isListening {
                    self.isListening = false
                    if self.audioEngine.isRunning {
                        self.audioEngine.stop()
                        self.audioEngine.inputNode.removeTap(onBus: 0)
                    }
                    self.finalizeRecognitionSession(deliverLatest: self.latestTranscript)
                }
            }
        }

        return true
    }

    /// After `endAudio()`, Apple sends a final result — unless we cancel the task too early. Never cancel until we finalize or time out.
    private func finalizeRecognitionSession(deliverLatest: String) {
        waitingForFinalAfterEndAudio = false
        finalizeTimeoutTask?.cancel()
        finalizeTimeoutTask = nil
        pendingTranscriptionWAV = pcmRecorder.takeWAVFile()
        cleanupRecognitionInfrastructure()
        deliverTranscriptIfNeeded(deliverLatest)
    }

    /// Best partial phrase Apple streamed while you were holding the orb (helps when the final hypothesis is wrong).
    var bestPartialTranscriptThisSession: String {
        longestPartialDuringSession.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func discardPendingRecording() {
        if let url = pendingTranscriptionWAV {
            try? FileManager.default.removeItem(at: url)
            pendingTranscriptionWAV = nil
        }
    }

    private func cleanupRecognitionInfrastructure() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }

    private func ensureSpeechAuthorized() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        @unknown default:
            return false
        }
    }

    private func ensureMicrophoneAuthorized() async -> Bool {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    func stopListening(deliverPartialTranscript: Bool = true) {
        guard isListening || recognitionRequest != nil else {
            if deliverPartialTranscript, !hasDeliveredTranscript {
                finalizeRecognitionSession(deliverLatest: latestTranscript)
            }
            return
        }
        isListening = false
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        waitingForFinalAfterEndAudio = deliverPartialTranscript
        // Do not cancel `recognitionTask` here — wait for the service to emit a final hypothesis after endAudio.

        guard deliverPartialTranscript else { return }

        finalizeTimeoutTask?.cancel()
        finalizeTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self else { return }
            guard !self.hasDeliveredTranscript else { return }
            let fallback = self.latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            self.finalizeRecognitionSession(deliverLatest: fallback)
        }
    }

    private func cleanupAudioTracking() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }

    private func deliverTranscriptIfNeeded(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hasDeliveredTranscript else { return }
        hasDeliveredTranscript = true
        /// Hand off the WAV for **this** utterance synchronously so async Whisper cannot race the next session.
        let wavHandoff = pendingTranscriptionWAV
        pendingTranscriptionWAV = nil
        onFinalText?(cleaned, wavHandoff)
        onPartialText = nil
        onFinalText = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isSpeaking = false
            self.ttsWordPulse = 0
            let done = self.onSpeechFinished
            self.onSpeechFinished = nil
            done?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isSpeaking = false
            self.ttsWordPulse = 0
            let done = self.onSpeechFinished
            self.onSpeechFinished = nil
            done?()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.ttsWordPulse += 1
        }
    }
}
