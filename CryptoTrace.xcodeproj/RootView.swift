import SwiftUI

struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    var body: some View {
        Group {
            if hasSeenOnboarding {
                ContentContainerView()
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: hasSeenOnboarding)
    }
}

// Replace this with your app's real root (e.g., MainTabView or similar)
struct ContentContainerView: View {
    var body: some View {
        RootTabView()
    }
}

#Preview {
    RootView()
}
