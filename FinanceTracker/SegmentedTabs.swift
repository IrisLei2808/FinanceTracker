import SwiftUI

struct SegmentedTabs: View {
    let tabs: [String]
    @Binding var selection: Int

    @Namespace private var ns

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = index
                    }
                } label: {
                    ZStack {
                        if selection == index {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor)
                                .matchedGeometryEffect(id: "seg-bg", in: ns)
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.clear)
                        }
                        Text(title)
                            .font(.subheadline).bold()
                            .foregroundStyle(selection == index ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                }
                .buttonStyle(.plain)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.08))
        )
    }
}
