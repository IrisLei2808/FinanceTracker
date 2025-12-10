import SwiftUI

struct OfflineView: View {
    let title: String
    let message: String
    var retry: (() -> Void)?

    @State private var bounce = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "wifi.slash")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .scaleEffect(bounce ? 1.05 : 0.95)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: bounce)
            }
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            if let retry {
                Button {
                    retry()
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { bounce = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

