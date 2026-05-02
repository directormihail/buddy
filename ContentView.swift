import SwiftUI

struct ContentView: View {
    @StateObject private var settings = BuddySettingsStore()
    @AppStorage(BuddyOnboarding.storageKey) private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ChatView()
                    .environmentObject(settings)
            } else {
                OnboardingView(onComplete: {
                    hasCompletedOnboarding = true
                })
                .environmentObject(settings)
            }
        }
        .preferredColorScheme(nil)
    }
}

#Preview {
    ContentView()
}
