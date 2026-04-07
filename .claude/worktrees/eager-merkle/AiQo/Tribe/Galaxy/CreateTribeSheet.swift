import SwiftUI
import SwiftData

struct CreateTribeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var tribeName: String = ""
    @State private var createdTribe: ArenaTribe?
    @State private var isCreating = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var onCreated: (ArenaTribe) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 44))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.aiqoSand)

                    Text("أنشئ قبيلتك")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(TribePalette.textPrimary)

                    Text("اختر اسم يمثل فريقك — تقدر تعدّله بعدين")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(TribePalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // حقل الاسم
                VStack(alignment: .trailing, spacing: 6) {
                    TextField("اسم القبيلة", text: $tribeName)
                        .font(.system(.title3, design: .rounded))
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.aiqoMint.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                        .focused($isFocused)

                    Text("\(tribeName.count)/20")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(TribePalette.textTertiary)
                }

                // معاينة
                if !tribeName.trimmingCharacters(in: .whitespaces).isEmpty {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.aiqoSand.opacity(0.5), Color.aiqoMint.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                            Text(String(tribeName.prefix(2)))
                                .font(.system(.callout, design: .rounded, weight: .bold))
                                .foregroundStyle(TribePalette.textPrimary)
                        }
                        Text(tribeName)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(TribePalette.textPrimary)
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.spring(response: 0.28, dampingFraction: 0.86), value: tribeName)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.red.opacity(0.8))
                        .transition(.opacity)
                }

                if let tribe = createdTribe {
                    // تم الإنشاء
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 36))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color(hex: "2D6B4A"))

                        Text("تم إنشاء القبيلة!")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(Color(hex: "2D6B4A"))

                        Text(tribe.inviteCode)
                            .font(.system(size: 32, weight: .heavy, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(TribePalette.textPrimary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.aiqoSand.opacity(0.12))
                            )

                        ShareLink(
                            item: String(format: NSLocalizedString("tribe.invite.shareText", value: "انضم لقبيلتي في AiQo! 💪\nالكود: %@\nhttps://aiqo.app/tribe/%@", comment: ""), tribe.inviteCode, tribe.inviteCode),
                            subject: Text(NSLocalizedString("tribe.invite.subject", value: "دعوة قبيلة AiQo", comment: "")),
                            message: Text(NSLocalizedString("tribe.invite.message", value: "انضم لقبيلتي في AiQo! 💪", comment: ""))
                        ) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text("شارك الرمز")
                            }
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(hex: "2D6B4A"))
                            )
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    Spacer()

                    Button { createTribe() } label: {
                        HStack {
                            if isCreating { ProgressView().tint(.white) }
                            Text("إنشاء القبيلة")
                                .font(.system(.headline, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    tribeName.trimmingCharacters(in: .whitespaces).count < 2
                                        ? Color.gray.opacity(0.4)
                                        : Color(hex: "2D6B4A")
                                )
                        )
                        .shadow(color: Color(hex: "2D6B4A").opacity(0.2), radius: 8, y: 4)
                    }
                    .disabled(tribeName.trimmingCharacters(in: .whitespaces).count < 2 || isCreating)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
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
            .onChange(of: tribeName) { _, val in
                if val.count > 20 { tribeName = String(val.prefix(20)) }
            }
        }
    }

    private func createTribe() {
        let name = tribeName.trimmingCharacters(in: .whitespaces)
        guard name.count >= 2 else { return }
        isCreating = true
        errorMessage = nil

        Task {
            let service = SupabaseArenaService.shared
            do {
                let tribe = try await service.createTribe(name: name, context: modelContext)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    createdTribe = tribe
                }
                onCreated(tribe)
            } catch {
                withAnimation {
                    let mapped = AiQoError.from(error)
                    if case .unknown = mapped {
                        errorMessage = NSLocalizedString("tribe.create.error", value: "ما قدرنا ننشئ القبيلة هسه. جرّب مرة ثانية.", comment: "")
                    } else {
                        errorMessage = mapped.errorDescription
                    }
                }
            }
            isCreating = false
        }
    }
}
