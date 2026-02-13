import SwiftUI

// MARK: - SwiftUI View
struct CircularTribeButtonView: View {
    var onTap: () -> Void
    
    @State private var isPressed = false
    @State private var feedbackTrigger = 0
    
    var body: some View {
        Button(action: {
            feedbackTrigger += 1
            onTap()
        }) {
            ZStack {
                // الخلفية الزجاجية
                Circle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                
                // الأيقونة
                Image(systemName: "person.3.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 60, height: 60) // الحجم الافتراضي
        }
        .buttonStyle(ScaleButtonStyle())
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }
}

// تأثير الضغط (Scaling)
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.snappy(duration: 0.3, extraBounce: 0.08), value: configuration.isPressed)
    }
}

// MARK: - UIKit Wrapper (للحفاظ على توافق المشروع الحالي)
final class CircularTribeButton: UIView {
    
    private var hostingController: UIHostingController<CircularTribeButtonView>?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSwiftUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSwiftUI()
    }
    
    private func setupSwiftUI() {
        // إنشاء واجهة SwiftUI
        let swiftUIView = CircularTribeButtonView { [weak self] in
            self?.sendActions(for: .primaryActionTriggered)
        }
        
        let host = UIHostingController(rootView: swiftUIView)
        host.view.backgroundColor = .clear // شفافية
        host.view.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(host.view)
        
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        self.hostingController = host
    }
    
    // محاكاة حدث الزر في UIKit
    func sendActions(for controlEvents: UIControl.Event) {
        // يمكنك هنا ربط الأكشن الخاص بك
        print("Tribe Button Tapped!")
    }
}
