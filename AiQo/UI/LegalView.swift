import SwiftUI

/// شاشة عرض السياسات القانونية (Privacy Policy + Terms of Service)
struct LegalView: View {
    enum LegalType {
        case privacyPolicy
        case termsOfService
        case acknowledgements

        var titleKey: String {
            switch self {
            case .privacyPolicy: return "legal.privacy.title"
            case .termsOfService: return "legal.terms.title"
            case .acknowledgements: return "legal.acknowledgements.title"
            }
        }

        var contentKey: String {
            switch self {
            case .privacyPolicy: return "legal.privacy.content"
            case .termsOfService: return "legal.terms.content"
            case .acknowledgements: return ""
            }
        }
    }

    let type: LegalType
    @Environment(\.dismiss) private var dismiss

    private var bodyText: String {
        switch type {
        case .acknowledgements:
            guard let url = Bundle.main.url(forResource: "ACKNOWLEDGEMENTS", withExtension: "md"),
                  let text = try? String(contentsOf: url, encoding: .utf8)
            else {
                return "ACKNOWLEDGEMENTS.md not bundled."
            }
            return text
        default:
            return type.contentKey.localized
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(bodyText)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(20)
            }
            .background(Color.black)
            .navigationTitle(type.titleKey.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

/// أزرار الروابط القانونية — تستخدم بشاشة الإعدادات أو الـ Paywall
struct LegalLinksView: View {
    @State private var showPrivacy = false
    @State private var showTerms = false

    var body: some View {
        HStack(spacing: 16) {
            Button {
                showPrivacy = true
            } label: {
                Text("legal.privacy.title".localized)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .buttonStyle(.plain)

            Text("·")
                .foregroundStyle(.white.opacity(0.3))

            Button {
                showTerms = true
            } label: {
                Text("legal.terms.title".localized)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showPrivacy) {
            LegalView(type: .privacyPolicy)
        }
        .sheet(isPresented: $showTerms) {
            LegalView(type: .termsOfService)
        }
    }
}

#Preview {
    LegalView(type: .privacyPolicy)
}
