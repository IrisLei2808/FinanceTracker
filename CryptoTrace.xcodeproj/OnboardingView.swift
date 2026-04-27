import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var page: Int = 0

    private struct Page: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let systemImage: String
    }

    private let pages: [Page] = [
        Page(title: "Start your crypto journey", subtitle: "Welcome to a new era of Finance! Create your account, track markets, and manage your portfolio.", systemImage: "shippingbox.circle.fill"),
        Page(title: "Easy Crypto, Big Rewards", subtitle: "Discover top coins, follow news, and get insights to help you make informed decisions.", systemImage: "sparkles.rectangle.stack"),
        Page(title: "Getting Started", subtitle: "Secure your assets and explore the app features.", systemImage: "bitcoinsign.circle.fill")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Skip") { finish() }
                    .opacity(page < pages.count - 1 ? 1 : 0)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { idx, p in
                    VStack(spacing: 20) {
                        Spacer(minLength: 0)
                        Image(systemName: p.systemImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundStyle(.blue)
                            .padding(.bottom, 10)
                        Text(p.title)
                            .font(.title2).bold()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Text(p.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Spacer(minLength: 0)
                    }
                    .tag(idx)
                    .padding()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack(spacing: 12) {
                if page > 0 {
                    Button(action: { withAnimation { page -= 1 } }) {
                        Text("Back")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Button(action: next) {
                    Text(page == pages.count - 1 ? "Get Started" : "Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
    }

    private func next() {
        if page < pages.count - 1 {
            withAnimation { page += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        hasSeenOnboarding = true
    }
}

#Preview {
    OnboardingView()
}
