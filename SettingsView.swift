import AVFoundation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: BuddySettingsStore
    @Binding var isPresented: Bool

    private var voices: [AVSpeechSynthesisVoice] { BuddyVoiceCatalog.selectableVoices }

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsScenicBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Make Buddy feel just right for you.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: 0x3D5A80).opacity(0.88))
                            .padding(.top, 4)

                        settingsSection(
                            title: "How Buddy sounds",
                            systemImage: "waveform.and.mic",
                            accent: Color(hex: 0x3B82F6)
                        ) {
                            voicePickerRow
                        }

                        settingsSection(
                            title: "How much Buddy says",
                            systemImage: "text.bubble.fill",
                            accent: BuddyColors.softPurple
                        ) {
                            replyLengthRowPicker
                        }

                        settingsSection(
                            title: "Your name",
                            systemImage: "person.crop.circle.fill",
                            accent: Color(hex: 0x14B8A6)
                        ) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Buddy will say hi to you and use this name in chat.")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(hex: 0x315F92).opacity(0.78))
                                    .fixedSize(horizontal: false, vertical: true)

                                TextField("Type your name…", text: $settings.displayName)
                                    .textContentType(.nickname)
                                    .autocorrectionDisabled()
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(hex: 0x25436B))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.white.opacity(0.95))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color(hex: 0x14B8A6).opacity(0.35),
                                                        Color(hex: 0x3B82F6).opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                            }
                        }

                        settingsSection(
                            title: "Little buzzes",
                            systemImage: "hand.tap.fill",
                            accent: Color(hex: 0xF59E0B)
                        ) {
                            Toggle(isOn: $settings.hapticsEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Happy taps")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    Text("A tiny bump when you use the talk button")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color(hex: 0x315F92).opacity(0.65))
                                }
                            }
                            .tint(
                                LinearGradient(
                                    colors: [Color(hex: 0x6366F1), Color(hex: 0x22D3EE)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        }

                        settingsSection(
                            title: "Welcome tour",
                            systemImage: "party.popper.fill",
                            accent: Color(hex: 0xEC4899)
                        ) {
                            Button {
                                BuddyOnboarding.isComplete = false
                                isPresented = false
                            } label: {
                                HStack(alignment: .center, spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(hex: 0xEC4899).opacity(0.2),
                                                        Color(hex: 0x8B5CF6).opacity(0.15)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "sparkles.rectangle.stack.fill")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [Color(hex: 0xEC4899), Color(hex: 0x8B5CF6)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Play the intro again")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Color(hex: 0x25436B))
                                        Text("See the friendly tour with the dancing robot")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color(hex: 0x315F92).opacity(0.72))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.right.circle.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(Color(hex: 0x8B5CF6).opacity(0.45))
                                }
                                .padding(.vertical, 2)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Closes settings and shows the onboarding screens")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: 0x315F92))
                }
            }
        }
    }

    private var replyLengthRowPicker: some View {
        HStack(spacing: 10) {
            ForEach(BuddyResponseLength.allCases) { len in
                let selected = settings.responseLength == len
                Button {
                    settings.responseLength = len
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(replyLengthIconFill(for: len))
                                    .frame(width: 36, height: 36)
                                Image(systemName: replyLengthSymbol(for: len))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(replyLengthIconTint(for: len))
                            }
                            Text(len.title)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: 0x0F172A))
                        }
                        Text(len.subtitle)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: 0x315F92).opacity(0.68))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.88)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selected ? Color(hex: 0xF1F5F9) : Color.white.opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                selected ? Color(hex: 0xCBD5E1) : Color(hex: 0xE2E8F0).opacity(0.9),
                                lineWidth: selected ? 1.5 : 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }

    private func replyLengthSymbol(for length: BuddyResponseLength) -> String {
        switch length {
        case .short: return "hare.fill"
        case .detailed: return "books.vertical.fill"
        }
    }

    private func replyLengthIconFill(for length: BuddyResponseLength) -> LinearGradient {
        switch length {
        case .short:
            return LinearGradient(
                colors: [Color(hex: 0xE0F2FE), Color(hex: 0xDBEAFE)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .detailed:
            return LinearGradient(
                colors: [Color(hex: 0xEDE9FE), Color(hex: 0xE0E7FF)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func replyLengthIconTint(for length: BuddyResponseLength) -> Color {
        switch length {
        case .short: return Color(hex: 0x2563EB)
        case .detailed: return Color(hex: 0x7C3AED)
        }
    }

    private func settingsSection<Content: View>(
        title: String,
        systemImage: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.28), accent.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent)
                }
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: 0x0F172A))
            }

            VStack(spacing: 0) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.95),
                                accent.opacity(0.25),
                                .white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color(hex: 0x1E3A5F).opacity(0.07), radius: 20, y: 10)
            .shadow(color: accent.opacity(0.12), radius: 28, y: 14)
        }
    }

    private var voicePickerRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Menu {
                Button("System default") {
                    settings.selectedVoiceIdentifier = ""
                }
                ForEach(voices, id: \.identifier) { voice in
                    Button(voice.name) {
                        settings.selectedVoiceIdentifier = voice.identifier
                    }
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0xDBEAFE), Color(hex: 0xE0F2FE)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x2563EB))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Speaking voice")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Text(settings.voiceMenuLabel)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: 0x315F92).opacity(0.75))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: 0x315F92).opacity(0.55))
                        .padding(8)
                        .background(Color(hex: 0xEFF6FF))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Backdrop

private struct SettingsScenicBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0xF0F9FF),
                    Color(hex: 0xEEF2FF),
                    Color(hex: 0xFDF4FF)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(hex: 0x60A5FA).opacity(0.22))
                .frame(width: 360, height: 360)
                .blur(radius: 55)
                .offset(x: -130, y: -300)

            Circle()
                .fill(BuddyColors.softPurple.opacity(0.2))
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .offset(x: 150, y: -220)

            Circle()
                .fill(Color(hex: 0xF9A8D4).opacity(0.16))
                .frame(width: 280, height: 280)
                .blur(radius: 45)
                .offset(x: -40, y: 420)

            ForEach(0 ..< 28, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: CGFloat(2 + i % 3), height: CGFloat(2 + i % 3))
                    .offset(
                        x: CGFloat((i * 47) % 300 - 150),
                        y: CGFloat((i * 61) % 700 - 350)
                    )
            }
            .allowsHitTesting(false)
        }
    }
}
