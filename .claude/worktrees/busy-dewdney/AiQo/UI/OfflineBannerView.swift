import SwiftUI

/// بانر يظهر أعلى الشاشة لما المستخدم بدون إنترنت
struct OfflineBannerView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 14, weight: .semibold))

                Text("offline.banner".localized)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.red.opacity(0.85))
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.35), value: networkMonitor.isConnected)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("offline.banner".localized)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

/// Modifier يضيف بانر الأوفلاين فوق أي view
struct OfflineBannerModifier: ViewModifier {
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            OfflineBannerView()
            content
        }
    }
}

extension View {
    func withOfflineBanner() -> some View {
        modifier(OfflineBannerModifier())
    }
}
