import SwiftUI

/// Shared gradient backdrop for main chat and settings (Part 7).
struct PremiumBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xF8FBFF), Color(hex: 0xEDF4FF), Color(hex: 0xE7EEFF)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(hex: 0x89B7FF).opacity(0.2))
                .frame(width: 330, height: 330)
                .blur(radius: 35)
                .offset(x: -150, y: -280)

            Circle()
                .fill(Color(hex: 0xC2A2FF).opacity(0.18))
                .frame(width: 290, height: 290)
                .blur(radius: 34)
                .offset(x: 170, y: -250)

            Circle()
                .fill(Color(hex: 0x7FCBFF).opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 38)
                .offset(x: 0, y: 320)

            ForEach(0 ..< 34, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(0.36))
                    .frame(width: CGFloat((i % 3) + 2), height: CGFloat((i % 3) + 2))
                    .offset(
                        x: CGFloat((i * 39) % 320 - 160),
                        y: CGFloat((i * 67) % 720 - 360)
                    )
            }
        }
    }
}
