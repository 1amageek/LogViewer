import SwiftUI

public struct LogRow: View {
    public static let textInsets = LogTextInsets(
        leading: 16,
        trailing: 16,
        top: 9,
        bottom: 8
    )

    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundStyle(Color(red: 0.96, green: 0.96, blue: 0.95))
            .padding(.leading, Self.textInsets.leading)
            .padding(.trailing, Self.textInsets.trailing)
            .padding(.top, Self.textInsets.top)
            .padding(.bottom, Self.textInsets.bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(backgroundColor)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
            }
    }

    private var backgroundColor: Color {
        let lowercased = text.lowercased()
        if lowercased.contains("error")
            || lowercased.contains("fault")
            || lowercased.contains("critical")
            || lowercased.contains("\"status\":5")
            || lowercased.contains("undefined results")
        {
            return Color(red: 0.31, green: 0.16, blue: 0.19)
        }

        if lowercased.contains("warning")
            || lowercased.contains(" warn ")
            || lowercased.contains("\"status\":4")
            || lowercased.contains("unifiedreasons")
            || lowercased.contains("interrupted")
            || lowercased.contains("connection interrupted")
        {
            return Color(red: 0.28, green: 0.26, blue: 0.15)
        }

        return Color(red: 0.14, green: 0.15, blue: 0.18)
    }
}
