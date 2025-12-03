import SwiftUI

struct USStocksView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("US Stocks")
                    .font(.title2).bold()
                Text("Placeholder screen. Hook up your stocks data and list here.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("US Stocks")
        }
    }
}

#Preview {
    USStocksView()
}
