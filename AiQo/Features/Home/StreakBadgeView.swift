import SwiftUI

/// بادج الـ Streak — يظهر بالـ Home Screen فوق الـ Aura
struct StreakBadgeView: View {
    @ObservedObject private var streakManager = StreakManager.shared

    var body: some View {
        if streakManager.currentStreak > 0 || streakManager.todayCompleted {
            HStack(spacing: 6) {
                // أيقونة النار
                Image(systemName: streakManager.todayCompleted ? "flame.fill" : "flame")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(flameColor)
                    .symbolEffect(.bounce, value: streakManager.todayCompleted)

                Text("\(streakManager.currentStreak)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(flameColor)
                    .contentTransition(.numericText())

                if streakManager.currentStreak >= 7 {
                    Text("🔥")
                        .font(.system(size: 11))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(flameColor.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(flameColor.opacity(0.2), lineWidth: 1)
                    )
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("streak \(streakManager.currentStreak) يوم متتالي")
        }
    }

    private var flameColor: Color {
        if streakManager.currentStreak >= 30 {
            return .purple
        } else if streakManager.currentStreak >= 7 {
            return .orange
        } else {
            return Color(red: 0.922, green: 0.780, blue: 0.576) // sand
        }
    }
}

/// بطاقة Streak تفصيلية — تظهر بالبروفايل
struct StreakDetailCard: View {
    @ObservedObject private var streakManager = StreakManager.shared

    private let calendar = Calendar.current
    private let mint = Color(red: 0.718, green: 0.890, blue: 0.792)
    private let sand = Color(red: 0.922, green: 0.780, blue: 0.576)

    var body: some View {
        VStack(spacing: 16) {
            // الهيدر
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("الالتزام")
                        .font(.system(size: 18, weight: .bold, design: .rounded))

                    Text(streakManager.motivationMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Streak الحالي
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(streakManager.currentStreak)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .contentTransition(.numericText())
                    }
                    Text("يوم متتالي")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // شبكة الأيام (آخر 4 أسابيع)
            streakCalendar

            // الإحصائيات
            HStack(spacing: 0) {
                statItem(
                    value: "\(streakManager.longestStreak)",
                    label: "أطول streak",
                    icon: "trophy.fill",
                    tint: .orange
                )

                Divider().frame(height: 30)

                statItem(
                    value: String(format: "%.0f%%", streakManager.weeklyConsistency),
                    label: "التزام الأسبوع",
                    icon: "chart.line.uptrend.xyaxis",
                    tint: mint
                )

                Divider().frame(height: 30)

                statItem(
                    value: streakManager.todayCompleted ? "✅" : "⬜️",
                    label: "اليوم",
                    icon: "checkmark.circle",
                    tint: streakManager.todayCompleted ? .green : .gray
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.66), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        )
    }

    // MARK: - Streak Calendar

    private var streakCalendar: some View {
        let today = calendar.startOfDay(for: Date())
        let activeDates = Set(streakManager.recentHistory.map { calendar.startOfDay(for: $0) })

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            // آخر 28 يوم
            ForEach(0..<28, id: \.self) { offset in
                let date = calendar.date(byAdding: .day, value: -(27 - offset), to: today) ?? today
                let isActive = activeDates.contains(calendar.startOfDay(for: date))
                let isToday = calendar.isDate(date, inSameDayAs: today)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(cellColor(isActive: isActive, isToday: isToday))
                    .frame(height: 16)
                    .overlay(
                        isToday ?
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(sand, lineWidth: 1.5) : nil
                    )
            }
        }
    }

    private func cellColor(isActive: Bool, isToday: Bool) -> Color {
        if isActive {
            return mint
        }
        return Color.gray.opacity(0.08)
    }

    private func statItem(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}

#Preview {
    VStack(spacing: 20) {
        StreakBadgeView()
        StreakDetailCard()
    }
    .padding()
    .background(Color(red: 0.95, green: 0.97, blue: 0.95))
}
