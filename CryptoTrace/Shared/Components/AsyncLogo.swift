import SwiftUI

struct AsyncLogo: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ZStack {
                    Circle().fill(Color.gray.opacity(0.15))
                    ProgressView().scaleEffect(0.6)
                }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            case .failure:
                Image(systemName: "bitcoinsign.circle")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(Circle())
            @unknown default:
                EmptyView()
            }
        }
        .clipShape(Circle())
    }
}

#Preview {
    VStack(spacing: 20) {
        AsyncLogo(url: URL(string: "https://s2.coinmarketcap.com/static/img/coins/64x64/1.png"))
            .frame(width: 44, height: 44)
        AsyncLogo(url: nil)
            .frame(width: 44, height: 44)
    }
    .padding()
}
