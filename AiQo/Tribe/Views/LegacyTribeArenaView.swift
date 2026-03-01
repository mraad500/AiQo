import SwiftUI
import UIKit

struct LegacyTribeArenaView: View {
    let energyCurrent: Int
    let energyTarget: Int
    let missions: [TribeMission]
    let canContribute: Bool
    let onContribute: (Int) -> Void

    @State private var isContributionSheetPresented = false

    private var remaining: Int {
        max(energyTarget - energyCurrent, 0)
    }

    private var energyProgress: Double {
        guard energyTarget > 0 else { return 0 }
        return min(Double(energyCurrent) / Double(energyTarget), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TribeGlassPanel(style: .soft, tint: UIColor.systemPurple) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("درع القبيلة")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))

                    Text("\(min(energyCurrent, energyTarget))/\(energyTarget)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    ProgressView(value: energyProgress)
                        .tint(.white.opacity(0.92))

                    Text(remaining == 0 ? "تم فتح الدرع ✅" : "باقي \(remaining) حتى نفتح الدرع")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        isContributionSheetPresented = true
                    } label: {
                        Text("مساهمة الآن")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.74))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canContribute)
                    .opacity(canContribute ? 1 : 0.55)
                }
            }

            TribeGlassPanel(style: .glass, tint: UIColor.systemIndigo) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("مهمات تعاونية")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))

                    ForEach(missions) { mission in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(mission.title)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                                Spacer()

                                Text("\(mission.progressValue)/\(mission.targetValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(
                                value: Double(min(mission.progressValue, mission.targetValue)),
                                total: Double(max(mission.targetValue, 1))
                            )
                            .tint(.white.opacity(0.9))

                            Text("تنتهي \(mission.endsAt.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.28))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
        .sheet(isPresented: $isContributionSheetPresented) {
            TribeContributionSheet { amount in
                onContribute(amount)
            }
            .presentationDetents([.fraction(0.34)])
        }
    }
}

private struct TribeContributionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (Int) -> Void

    private let options: [(title: String, amount: Int)] = [
        ("+20 طاقة (مشي)", 20),
        ("+15 طاقة (تمرين)", 15),
        ("+10 طاقة (ماء)", 10),
        ("+10 طاقة (هدوء)", 10)
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Button(option.title) {
                        onSelect(option.amount)
                        dismiss()
                    }
                }
            }
            .navigationTitle("اختر المساهمة")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
