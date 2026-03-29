import SwiftUI

struct MessageBubble<Content: View>: View {
    let isUser: Bool
    let timestamp: Date
    private let content: Content
    @State private var showTimestamp = false

    init(
        isUser: Bool,
        timestamp: Date = Date(),
        @ViewBuilder content: () -> Content
    ) {
        self.isUser = isUser
        self.timestamp = timestamp
        self.content = content()
    }

    private var bubbleColor: Color {
        if isUser {
            return Color(red: 0.77, green: 0.94, blue: 0.86) // #C4F0DB Mint
        }
        return Color(red: 0.97, green: 0.84, blue: 0.64) // #F8D6A3 Sand
    }

    private var textColor: Color {
        Color.black.opacity(0.85)
    }

    private var bubbleCorners: UnevenRoundedRectangle {
        if isUser {
            return UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 20,
                bottomTrailingRadius: 4,
                topTrailingRadius: 20
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 4,
                bottomTrailingRadius: 20,
                topTrailingRadius: 20
            )
        }
    }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            content
                .foregroundStyle(textColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    bubbleCorners
                        .fill(bubbleColor)
                )
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
                .onLongPressGesture(minimumDuration: 0.3) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTimestamp.toggle()
                    }
                }

            if showTimestamp {
                Text(relativeTimestamp)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }

    private var relativeTimestamp: String {
        let now = Date()
        let interval = now.timeIntervalSince(timestamp)
        let localeID = AppSettingsStore.shared.appLanguage == .english ? "en" : "ar"

        if interval < 60 {
            return NSLocalizedString("time.now", value: "الحين", comment: "Just now timestamp")
        }

        let minutes = Int(interval / 60)
        if minutes < 60 {
            return String(format: NSLocalizedString("time.minutesAgo", value: "قبل %d دقايق", comment: "Minutes ago timestamp"), minutes)
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(timestamp) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            formatter.locale = Locale(identifier: localeID)
            return formatter.string(from: timestamp)
        }

        if calendar.isDateInYesterday(timestamp) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm"
            formatter.locale = Locale(identifier: localeID)
            return NSLocalizedString("time.yesterday", value: "البارحة", comment: "Yesterday timestamp") + " " + formatter.string(from: timestamp)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM h:mm"
        formatter.locale = Locale(identifier: localeID)
        return formatter.string(from: timestamp)
    }
}
