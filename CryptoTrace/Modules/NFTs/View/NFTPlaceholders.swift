import SwiftUI

// Simple header used at the top of the NFT list.
// Shows a friendly title and an optional loading indicator.
struct CartoonNFTHeader: View {
    let isLoading: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
                Image(systemName: "hexagon")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text("Discover NFT Collections")
                    .font(.headline)
                Text("Browse top and hottest collections.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isLoading {
                ProgressView()
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

// Simple shimmer-like loading row placeholder.
// Keeps layout similar to a list row with an image and text blocks.
struct ShimmerRow: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(shimmer)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(shimmer)
                    .frame(width: 160, height: 14)
                RoundedRectangle(cornerRadius: 6)
                    .fill(shimmer)
                    .frame(width: 120, height: 12)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(shimmer)
                    .frame(width: 80, height: 14)
                RoundedRectangle(cornerRadius: 6)
                    .fill(shimmer)
                    .frame(width: 60, height: 12)
            }
        }
        .redacted(reason: .placeholder)
        .onAppear { animate() }
    }

    private var shimmer: LinearGradient {
        LinearGradient(
            colors: [
                Color.gray.opacity(0.15),
                Color.gray.opacity(0.06),
                Color.gray.opacity(0.15)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func animate() {
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            phase = 1
        }
    }
}
