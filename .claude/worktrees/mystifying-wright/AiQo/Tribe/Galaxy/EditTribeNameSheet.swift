import SwiftUI

struct EditTribeNameSheet: View {
    let currentName: String
    var onSave: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var newName: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            // العنوان
            HStack {
                Button("إلغاء") { dismiss() }
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(TribePalette.textSecondary)

                Spacer()

                Text("تعديل الاسم")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(TribePalette.textPrimary)

                Spacer()

                Button("حفظ") {
                    onSave(newName)
                    dismiss()
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(hex: "2D6B4A"))
                .disabled(newName.trimmingCharacters(in: .whitespaces).count < 2)
            }

            // حقل الإدخال
            TextField("اسم القبيلة", text: $newName)
                .font(.system(.title3, design: .rounded))
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.plain)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.aiqoMint.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                )
                .focused($isFocused)

            HStack {
                Spacer()
                Text("\(newName.count)/20")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(TribePalette.textTertiary)
            }

            Spacer()
        }
        .padding(20)
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            newName = currentName
            isFocused = true
        }
        .onChange(of: newName) { _, val in
            if val.count > 20 { newName = String(val.prefix(20)) }
        }
    }
}
