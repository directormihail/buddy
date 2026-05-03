import SwiftUI

// MARK: - Welcome

struct WelcomeView: View {
    @Binding var name: String
    let onStart: () -> Void

    @State private var welcomeBobOffset: CGFloat = 0
    @FocusState private var isNameFocused: Bool

    private var canStart: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BuddyColors.lightBlue.opacity(0.75), BuddyColors.softPurple.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 26) {
                    BuddyRobotView(phase: .idle)
                        .frame(height: 260)
                        .offset(y: welcomeBobOffset)

                    Text("Hi! I'm Buddy")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Your buddy for big questions")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)

                    TextField("What should I call you?", text: $name)
                        .focused($isNameFocused)
                        .textContentType(.nickname)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.continue)
                        .onSubmit {
                            if canStart {
                                isNameFocused = false
                                onStart()
                            }
                        }
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 18)
                        .frame(height: 58)
                        .background(.white.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 24)

                    Button {
                        isNameFocused = false
                        onStart()
                    } label: {
                        Text("Let's start!")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                            .background(BuddyColors.warmYellow)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    }
                    .disabled(!canStart)
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                welcomeBobOffset = 6
            }
        }
    }
}
