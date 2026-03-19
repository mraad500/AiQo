import SwiftUI

/// رسالة خطأ مؤقتة تظهر بأسفل الشاشة
struct ErrorToastView: View {
    let message: String
    let recovery: String?
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.yellow)

                Text(message)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer(minLength: 4)

                if let onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let recovery {
                Text(recovery)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Modifier يدير عرض الأخطاء تلقائياً
struct ErrorToastModifier: ViewModifier {
    @Binding var error: AiQoError?
    @State private var showToast = false

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content

            if showToast, let error {
                ErrorToastView(
                    message: error.localizedDescription,
                    recovery: error.recoverySuggestion
                ) {
                    withAnimation {
                        self.error = nil
                        showToast = false
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .onChange(of: error != nil) { _, hasError in
            if hasError {
                withAnimation(.spring(response: 0.35)) {
                    showToast = true
                }
                // Auto dismiss after 4 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation {
                        showToast = false
                        self.error = nil
                    }
                }
            }
        }
    }
}

extension View {
    func errorToast(_ error: Binding<AiQoError?>) -> some View {
        modifier(ErrorToastModifier(error: error))
    }
}
