import SwiftUI
import SwiftData

struct JoinTribeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var inviteCode: String = ""
    @State private var errorMessage: String?
    @State private var joinedTribeName: String?
    @State private var isJoining = false
    @FocusState private var isFocused: Bool

    var onJoined: (String) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("انضم لقبيلة")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(TribePalette.textPrimary)

                Text("ادخل رمز الدعوة اللي وصلك")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(TribePalette.textSecondary)

                // حقل الرمز
                TextField("AQ-XXXX", text: $inviteCode)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.aiqoMint.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(
                                        errorMessage != nil
                                            ? Color.red.opacity(0.35)
                                            : Color.white.opacity(0.2),
                                        lineWidth: errorMessage != nil ? 1.5 : 0.5
                                    )
                            )
                    )
                    .focused($isFocused)
                    .onChange(of: inviteCode) { _, _ in errorMessage = nil }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.red.opacity(0.8))
                        .transition(.opacity)
                }

                if let name = joinedTribeName {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color(hex: "2D6B4A"))
                        Text("انضممت لـ \(name)!")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(TribePalette.textPrimary)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    Button { joinTribe() } label: {
                        HStack {
                            if isJoining { ProgressView().tint(.white) }
                            Text("انضم")
                                .font(.system(.headline, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    inviteCode.count < 6
                                        ? Color.gray.opacity(0.4)
                                        : Color(hex: "2D6B4A")
                                )
                        )
                    }
                    .disabled(inviteCode.count < 6 || isJoining)
                }

                Spacer()
            }
            .padding(24)
            .background(
                LinearGradient(
                    colors: [TribePalette.backgroundTop, TribePalette.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("إغلاق") { dismiss() }
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color(hex: "2D6B4A"))
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .onAppear { isFocused = true }
        }
    }

    private func joinTribe() {
        let code = inviteCode.trimmingCharacters(in: .whitespaces).uppercased()
        guard code.count >= 6 else {
            withAnimation { errorMessage = NSLocalizedString("tribe.join.tooShort", value: "الرمز لازم يكون بصيغة AQ-XXXX", comment: "") }
            return
        }

        let codePattern = /^AQ-[A-Z0-9]{4}$/
        guard code.wholeMatch(of: codePattern) != nil else {
            withAnimation { errorMessage = NSLocalizedString("tribe.join.invalidCode", value: "الكود غلط، تأكد منه وحاول مرة ثانية", comment: "") }
            return
        }

        isJoining = true

        Task {
            let service = SupabaseArenaService.shared
            do {
                let tribe = try await service.joinTribe(inviteCode: code, context: modelContext)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    joinedTribeName = tribe.name
                }
                onJoined(tribe.name)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                dismiss()
            } catch {
                withAnimation {
                    let mapped = AiQoError.from(error)
                    switch mapped {
                    case .tribeFull:
                        errorMessage = "القبيلة ممتلية، دور قبيلة ثانية"
                    case .tribeAlreadyJoined:
                        errorMessage = "أنت عضو بالقبيلة هذي أساساً"
                    case .noInternet:
                        errorMessage = "تأكد من اتصالك بالإنترنت وجرّب مرة ثانية"
                    case .unknown:
                        // Supabase PGRST116 = invite code not found
                        let desc = error.localizedDescription.lowercased()
                        if desc.contains("pgrst116") || desc.contains("no rows") || desc.contains("not found") {
                            errorMessage = "الكود غلط، تأكد منه"
                        } else {
                            errorMessage = "ما قدرنا نوصلك بالقبيلة هسه. جرّب مرة ثانية."
                        }
                    default:
                        errorMessage = mapped.errorDescription
                    }
                }
            }
            isJoining = false
        }
    }
}
