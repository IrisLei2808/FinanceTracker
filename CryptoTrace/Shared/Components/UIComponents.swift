import SwiftUI

// Visualizes a percent change as a horizontal bar.
// - Positive values fill to the right in green.
// - Negative values fill to the left in red.
// - Percent is expected in percent points (e.g., 5.2 for +5.2%).
struct ChangeBar: View {
    let percent: Double
    // Clamp the absolute percentage used for fill to a reasonable max to avoid overfilling.
    private let maxMagnitude: Double = 20 // +/-20% maps to full half-width

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let half = w / 2.0

            // Map percent magnitude to [0, half] width
            let magnitude = min(abs(percent), maxMagnitude) / maxMagnitude
            let fillWidth = CGFloat(magnitude) * half

            ZStack(alignment: .center) {
                // Background track
                RoundedRectangle(cornerRadius: h / 2)
                    .fill(Color.gray.opacity(0.15))

                // Midline
                Rectangle()
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 1)

                // Fill
                HStack(spacing: 0) {
                    if percent < 0 {
                        // Negative: fill from center to left
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(Color.red.opacity(0.6))
                            .frame(width: fillWidth, height: h)
                    } else if percent > 0 {
                        // Positive: fill from center to right
                        Rectangle()
                            .fill(Color.green.opacity(0.6))
                            .frame(width: fillWidth, height: h)
                        Spacer(minLength: 0)
                    } else {
                        // Zero: no fill
                        Spacer(minLength: 0)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: h / 2))
            }
        }
        .accessibilityLabel("Change bar")
        .accessibilityValue("\(formatChange(percent))")
    }
}

// A small capsule showing a titled percentage change (e.g., "24h +2.5%") with color semantics.
struct ChangePill: View {
    let title: String
    let value: Double

    var body: some View {
        let isUp = value >= 0
        HStack(spacing: 6) {
            Text(title)
                .font(.caption).bold()
            HStack(spacing: 4) {
                Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                Text(formatChange(value))
                    .font(.caption).bold()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background((isUp ? Color.green.opacity(0.15) : Color.red.opacity(0.15)), in: Capsule())
        .foregroundStyle(isUp ? .green : .red)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) change")
        .accessibilityValue(formatChange(value))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        Text("ChangeBar")
        ChangeBar(percent: 12.5)
            .frame(height: 8)
        ChangeBar(percent: -7.3)
            .frame(height: 8)
        ChangeBar(percent: 0)
            .frame(height: 8)

        Text("ChangePill")
        HStack {
            ChangePill(title: "1h", value: 1.23)
            ChangePill(title: "24h", value: -3.45)
        }
    }
    .padding()
}
