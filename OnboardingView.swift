import AVFoundation
import Speech
import SwiftUI

/// First-launch flow: premium presentation, voice permissions after friendly framing.
struct OnboardingView: View {
    var onComplete: () -> Void

    @EnvironmentObject private var settings: BuddySettingsStore
    @State private var page = 0
    @State private var permissionPhase: PermissionPhase = .idle

    private enum PermissionPhase {
        case idle
        case requesting
        case done
    }

    private let pageCount = 3

    var body: some View {
        ZStack {
            OnboardingAmbientBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topChrome

                headerSeparator

                TabView(selection: $page) {
                    pageMeetBuddy
                        .tag(0)
                    pageHowItWorks
                        .tag(1)
                    pageVoicePrivacy
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.86), value: page)

                bottomChrome
            }
        }
        .preferredColorScheme(nil)
    }

    // MARK: - Chrome

    private var topChrome: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Buddy")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0x1E3A5F), Color(hex: 0x5B7FD1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Quick answers")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: 0x64748B))
                    .tracking(0.3)
            }

            Spacer(minLength: 12)

            Button {
                finishOnboarding()
            } label: {
                Text("Skip")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: 0x475569))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.55))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.65), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip onboarding")
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// Visible boundary under the title row — mascot stage stays below this line.
    private var headerSeparator: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0xCBD5E1).opacity(0.55),
                            Color(hex: 0xE2E8F0).opacity(0.35)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal, 20)

            Color.clear.frame(height: 10)
        }
    }

    private var bottomChrome: some View {
        VStack(spacing: 14) {
            progressBar

            Text(stepHint)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: 0x64748B).opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: 0xF8FAFC).opacity(0), Color(hex: 0xF8FAFC).opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
            .offset(y: 24)
            .allowsHitTesting(false)
        )
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: 0xCBD5E1).opacity(0.45))
                    .frame(height: 5)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x6366F1), Color(hex: 0x22D3EE)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, w * CGFloat(page + 1) / CGFloat(pageCount)), height: 5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.82), value: page)
            }
        }
        .frame(height: 5)
        .padding(.horizontal, 48)
        .padding(.bottom, 4)
    }

    private var stepHint: String {
        switch page {
        case 0:
            return "Swipe for the next tip →"
        case 1:
            return "One gesture — hold to talk, release to send."
        default:
            return permissionPhase == .done ? "You're set. Tap below to open Buddy." : "Next: allow mic & speech when iOS asks."
        }
    }

    // MARK: - Pages

    private var pageMeetBuddy: some View {
        OnboardingPageShell(pageIndex: 0, totalPages: pageCount) {
            eyebrow("Ask anything")
            title("There are no stupid\nquestions.")
            bodyCopy(
                "Buddy is a lightning-fast voice companion — tap the orb, ask whatever’s on your mind, and get a tight reply. No threads, no clutter."
            )

            featureRow(
                icon: "bolt.fill",
                title: "Seconds, not scrolls",
                subtitle: "Short replies tuned for voice"
            )
            featureRow(
                icon: "bubble.left.and.bubble.right.fill",
                title: "Talk like a human",
                subtitle: "Hold · speak · release"
            )
            featureRow(
                icon: "sparkles",
                title: "Zero homework vibe",
                subtitle: "Quick chats, no typing marathon"
            )
        }
    }

    private var pageHowItWorks: some View {
        OnboardingPageShell(pageIndex: 1, totalPages: pageCount) {
            eyebrow("How it works")
            title("Hold. Speak.\nLet go.")
            bodyCopy(
                "Press and hold the orb while you talk. When you release, Buddy transcribes, thinks, and reads the answer aloud — like a premium push-to-talk assistant."
            )

            orbPreviewCard
        }
    }

    private var pageVoicePrivacy: some View {
        OnboardingPageShell(pageIndex: 2, totalPages: pageCount, bottomInset: 140) {
            eyebrow("Privacy")
            title("Mic on your terms.")
            bodyCopy(
                "We only listen while your finger is on the orb. Speech recognition turns your voice into text on-device first; nothing hits the network until you send a message."
            )

            HStack(spacing: 12) {
                privacyMiniCard(icon: "mic.fill", label: "Mic", sub: "While holding")
                privacyMiniCard(icon: "waveform", label: "Speech", sub: "On release")
            }
            .padding(.top, 4)

            VStack(spacing: 14) {
                if permissionPhase == .done {
                    primaryButton(title: "Open Buddy", showsProgress: false, disabled: false) {
                        finishOnboarding()
                    }
                } else {
                    primaryButton(
                        title: permissionPhase == .requesting ? "Follow the prompts…" : "Enable voice — show iOS sheet",
                        showsProgress: permissionPhase == .requesting,
                        disabled: permissionPhase == .requesting
                    ) {
                        Task { await requestVoicePermissionsFlow() }
                    }
                    Text("You’ll see Apple’s permission dialogs next — that’s normal.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: 0x64748B))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Pieces

    private func eyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: 0x6366F1))
            .tracking(1.6)
            .padding(.bottom, 2)
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: 0x0F172A))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 8)
    }

    private func bodyCopy(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .regular, design: .rounded))
            .foregroundStyle(Color(hex: 0x475569))
            .lineSpacing(5)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 18)
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xEEF2FF), Color(hex: 0xE0F2FE)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x4F46E5))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: 0x1E293B))
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: 0x64748B))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    private var orbPreviewCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: 0x93C5FD).opacity(0.5), Color(hex: 0x6366F1).opacity(0.15)],
                            center: .center,
                            startRadius: 4,
                            endRadius: 52
                        )
                    )
                    .frame(width: 88, height: 88)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x7DD3FC), Color(hex: 0x4F46E5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 62, height: 62)
                    .overlay {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .shadow(color: Color(hex: 0x6366F1).opacity(0.35), radius: 16, y: 8)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Voice orb")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: 0x1E293B))
                Text("Hold = live mic · Release = send")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: 0x64748B))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glassCardBackground())
    }

    private func privacyMiniCard(icon: String, label: String, sub: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(hex: 0x4F46E5))
                .frame(height: 28)
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: 0x1E293B))
            Text(sub)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: 0x64748B))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .background(glassCardBackground())
    }

    private func glassCardBackground() -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.72))
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.95), Color.white.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color(hex: 0x1E293B).opacity(0.06), radius: 24, y: 12)
    }

    private func primaryButton(title: String, showsProgress: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if showsProgress {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x4F46E5), Color(hex: 0x06B6D4)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color(hex: 0x4F46E5).opacity(0.38), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    @MainActor
    private func requestVoicePermissionsFlow() async {
        guard permissionPhase != .requesting else { return }
        permissionPhase = .requesting

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { _ in
                cont.resume()
            }
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { _ in
                cont.resume()
            }
        }

        permissionPhase = .done
        BuddyHaptics.softAck(enabled: settings.hapticsEnabled)
    }

    private func finishOnboarding() {
        onComplete()
    }
}

// MARK: - Page container + hero

private struct OnboardingPageShell<Content: View>: View {
    let pageIndex: Int
    let totalPages: Int
    var bottomInset: CGFloat = 100
    @ViewBuilder var content: () -> Content

    /// Space between mascot (same framing as chat) and body copy.
    private let heroToCopyGap: CGFloat = 36

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeroRobot(pageIndex: pageIndex, totalPages: totalPages)
                    .padding(.top, 12)
                    .padding(.bottom, heroToCopyGap)

                content()
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
            .padding(.bottom, bottomInset)
        }
    }
}

private struct OnboardingHeroRobot: View {
    let pageIndex: Int
    let totalPages: Int

    /// Same layout contract as `ChatView` (`BuddyRobotView.frame(height: 430)`).
    private let robotLayoutHeight: CGFloat = 430

    var body: some View {
        ZStack {
            // Soft floor glow — behind feet only; never clipped with the robot.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0x6366F1).opacity(0.14),
                            Color(hex: 0x22D3EE).opacity(0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 100
                    )
                )
                .frame(width: 280, height: 56)
                .offset(y: robotLayoutHeight * 0.42)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let bob = sin(t * 6.2) * 2.5
                let sway = sin(t * 4.8) * 5
                let tilt = sin(t * 4.8) * 2.2
                let progress = (CGFloat(pageIndex) + 0.5) / CGFloat(max(totalPages, 1))
                let journey = (progress - 0.5) * 14

                BuddyRobotView(interactionPhase: .idle)
                    .frame(height: robotLayoutHeight)
                    .offset(x: journey + sway, y: bob)
                    .rotationEffect(.degrees(tilt))
            }
        }
        .frame(maxWidth: .infinity)
        // Breathing room so idle hover (lifts mascot ~10pt) never clips the head.
        .padding(.top, 20)
        .padding(.bottom, 8)
        .padding(.horizontal, 8)
    }
}

// MARK: - Background

private struct OnboardingAmbientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0xF8FAFC),
                    Color(hex: 0xEEF2FF),
                    Color(hex: 0xECFEFF)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft aurora blobs
            Circle()
                .fill(Color(hex: 0x818CF8).opacity(0.18))
                .frame(width: 420, height: 420)
                .blur(radius: 70)
                .offset(x: -120, y: -320)

            Circle()
                .fill(Color(hex: 0x22D3EE).opacity(0.14))
                .frame(width: 340, height: 340)
                .blur(radius: 60)
                .offset(x: 140, y: -260)

            Circle()
                .fill(Color(hex: 0xC084FC).opacity(0.1))
                .frame(width: 280, height: 280)
                .blur(radius: 55)
                .offset(x: -80, y: 380)

            ForEach(0 ..< 52, id: \.self) { i in
                Circle()
                    .fill(Color(hex: 0x64748B).opacity(0.05))
                    .frame(width: CGFloat(1 + i % 3), height: CGFloat(1 + i % 3))
                    .offset(
                        x: CGFloat((i * 53) % 340 - 170),
                        y: CGFloat((i * 79) % 760 - 380)
                    )
            }
            .allowsHitTesting(false)
        }
    }
}
