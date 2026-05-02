import AVFoundation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: BuddySettingsStore
    @Binding var isPresented: Bool

    private var voices: [AVSpeechSynthesisVoice] { BuddyVoiceCatalog.selectableVoices }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        settingsSection(title: "Voice") {
                            voicePickerRow
                        }

                        settingsSection(title: "Replies") {
                            Picker("", selection: $settings.responseLength) {
                                ForEach(BuddyResponseLength.allCases) { len in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(len.title)
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        Text(len.subtitle)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color(hex: 0x315F92).opacity(0.65))
                                    }
                                    .tag(len)
                                }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                        }

                        settingsSection(title: "Name") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Buddy will greet you and use this name in chat.")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(hex: 0x315F92).opacity(0.72))

                                TextField("Call me…", text: $settings.displayName)
                                    .textContentType(.nickname)
                                    .autocorrectionDisabled()
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(hex: 0x25436B))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.92))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }

                        settingsSection(title: "Feedback") {
                            Toggle(isOn: $settings.hapticsEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Haptics")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    Text("Light taps when using the voice orb")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color(hex: 0x315F92).opacity(0.65))
                                }
                            }
                            .tint(Color(hex: 0x4A7FD9))
                        }

                        settingsSection(title: "Onboarding") {
                            Button {
                                BuddyOnboarding.isComplete = false
                                isPresented = false
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: "sparkles.rectangle.stack")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(Color(hex: 0x4A7FD9))
                                        .frame(width: 36, height: 36)
                                        .background(Color(hex: 0x4A7FD9).opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Replay introduction")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Color(hex: 0x25436B))
                                        Text("Walk through the welcome tour again")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color(hex: 0x315F92).opacity(0.72))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color(hex: 0x315F92).opacity(0.45))
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Closes settings and shows the onboarding screens")
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: 0x47607D).opacity(0.75))
                .tracking(0.6)

            VStack(spacing: 0) {
                content()
            }
            .padding(14)
            .background(Color.white.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
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
                HStack {
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
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
