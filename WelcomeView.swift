import SwiftUI

// MARK: - Welcome

struct WelcomeView: View {
    @Binding var name: String
    let onStart: () -> Void

    @State private var welcomeBobOffset: CGFloat = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BuddyColors.lightBlue.opacity(0.75), BuddyColors.softPurple.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 26) {
                BuddyRobotView(interactionPhase: .idle)
                    .frame(height: 260)
                    .offset(y: welcomeBobOffset)

                Text("Hi! I'm Buddy")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                TextField("What's your name?", text: $name)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 18)
                    .frame(height: 58)
                    .background(.white.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 24)

                Button {
                    onStart()
                } label: {
                    Text("Let's Chat!")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(BuddyColors.warmYellow)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 30)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                welcomeBobOffset = 6
            }
        }
    }
}
