import SwiftUI

struct WatchConnectionStatusButton: View {
    let status: WatchConnectionStatus
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "applewatch.side.right")
                    .font(.system(size: 19, weight: .bold))

                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .lineLimit(1)

                Spacer(minLength: 12)

                Image(systemName: accessoryIcon)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(.black.opacity(0.88))
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .frame(height: 65)
            .background(backgroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: 12, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var title: String {
        switch status {
        case .connected:
            return "Apple Watch متصلة"
        case .disconnected:
            return "Apple Watch غير متصلة"
        case .checking:
            return "جاري التحقق من Apple Watch"
        }
    }

    private var accessoryIcon: String {
        switch status {
        case .connected:
            return "checkmark.circle.fill"
        case .disconnected:
            return "xmark.circle.fill"
        case .checking:
            return "ellipsis.circle.fill"
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .connected:
            return WorkoutTheme.pastelMint
        case .disconnected:
            return WorkoutTheme.pastelBeige
        case .checking:
            return WorkoutTheme.pastelBeige.opacity(0.92)
        }
    }

    private var shadowColor: Color {
        switch status {
        case .connected:
            return WorkoutTheme.pastelMint.opacity(0.28)
        case .disconnected:
            return WorkoutTheme.pastelBeige.opacity(0.18)
        case .checking:
            return WorkoutTheme.pastelBeige.opacity(0.22)
        }
    }

    private var strokeOpacity: Double {
        switch status {
        case .connected:
            return 0.10
        case .disconnected, .checking:
            return 0.14
        }
    }
}

#Preview("Watch Status") {
    VStack(spacing: 16) {
        WatchConnectionStatusButton(status: .connected)
        WatchConnectionStatusButton(status: .disconnected)
        WatchConnectionStatusButton(status: .checking)
    }
    .padding()
    .background(WorkoutTheme.darkSky.ignoresSafeArea())
}
