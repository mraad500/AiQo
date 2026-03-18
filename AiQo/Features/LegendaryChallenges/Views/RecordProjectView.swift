import SwiftUI
import SwiftData

/// شاشة المشروع الرئيسية — تعرض تقدم مشروع كسر الرقم القياسي
struct RecordProjectView: View {
    let project: RecordProject
    @State private var checkpointInput = ""
    @State private var showCheckpointConfirmation = false
    @State private var showWeeklyReview = false
    @State private var showEndConfirmation = false
    @State private var showFinalEndConfirmation = false
    @State private var weekPlan: WeekPlanData?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                progressCard
                weeklyPlanSection
                measurementSection
                reviewButton
                captainMessageCard
                endProjectButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [Color.white, GymTheme.mint.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("المشروع")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            weekPlan = RecordProjectManager.shared.currentWeekPlan(for: project)
        }
        .sheet(isPresented: $showWeeklyReview) {
            NavigationStack {
                WeeklyReviewView(project: project)
            }
        }
        .alert("إنهاء المشروع", isPresented: $showEndConfirmation) {
            Button("إلغاء", role: .cancel) {}
            Button("نعم، متأكد") { showFinalEndConfirmation = true }
        } message: {
            Text("متأكد تبي تنهي مشروع كسر رقم \"\(project.recordTitle)\"؟")
        }
        .alert("⚠️ تأكيد نهائي", isPresented: $showFinalEndConfirmation) {
            Button("إلغاء", role: .cancel) {}
            Button("احذف المشروع نهائياً", role: .destructive) {
                RecordProjectManager.shared.abandonProject(project)
                dismiss()
            }
        } message: {
            Text("هالخطوة ما تنعكس. بيتم حذف كل بيانات المشروع والخطة المثبتة. متأكد 100%؟")
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: 16) {
            Text(project.recordTitle)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary)

            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: project.progressFraction)
                    .stroke(GymTheme.mint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: project.progressFraction)

                VStack(spacing: 2) {
                    Text("\(Int(project.progressFraction * 100))%")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.primary)

                    Text("الأسبوع \(project.currentWeek) من \(project.totalWeeks)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.45))
                }
            }
            .frame(width: 120, height: 120)

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("الهدف")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.45))
                    Text("\(formatValue(project.targetValue)) \(project.unit)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(GymTheme.mint)
                }

                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 1, height: 30)

                VStack(spacing: 4) {
                    Text("أفضل أداء")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.45))
                    Text("\(formatValue(project.bestPerformance)) \(project.unit)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(GymTheme.beige.opacity(0.2))
        )
    }

    // MARK: - Weekly Plan Section

    private var weeklyPlanSection: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text("خطة هذا الأسبوع")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary)

            if let weekPlan {
                ForEach(weekPlan.days) { day in
                    dayRow(day)
                }
            } else {
                Text("جاري تحميل الخطة...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func dayRow(_ day: DayPlanData) -> some View {
        HStack(spacing: 12) {
            Circle()
                .stroke(day.type == "rest" ? Color.primary.opacity(0.15) : GymTheme.mint, lineWidth: 2)
                .frame(width: 24, height: 24)
                .overlay {
                    if day.type == "rest" {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.primary.opacity(0.3))
                    }
                }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(day.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)

                Text(day.details)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }

            Text("يوم \(day.day)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.35))
                .frame(width: 40)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(day.type == "rest" ? Color(hex: "F7F7F7") : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Measurement Section

    private var measurementSection: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text("قياس الأسبوع")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary)

            Text("كم \(project.unit) قدرت تسوي؟")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.55))

            HStack(spacing: 12) {
                Button {
                    if let value = Double(checkpointInput) {
                        RecordProjectManager.shared.logPerformance(value, for: project)
                        checkpointInput = ""
                        showCheckpointConfirmation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCheckpointConfirmation = false
                        }
                    }
                } label: {
                    Text("سجّل")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(GymTheme.mint.opacity(0.4))
                        )
                }
                .buttonStyle(.plain)

                TextField("الرقم", text: $checkpointInput)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "F2F2F2"))
                    )
            }

            if showCheckpointConfirmation {
                Text("تم التسجيل ✓")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(GymTheme.mint)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(GymTheme.beige.opacity(0.15))
        )
    }

    // MARK: - Review Button

    private var reviewButton: some View {
        Button {
            showWeeklyReview = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.3))

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("📋 المراجعة وضبط البوصلة")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)

                    Text("مراجعة أسبوعية مع الكابتن")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.45))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: "F7F7F7"))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Captain Message

    private var captainMessageCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 14))
                .foregroundStyle(GymTheme.mint)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("🗨️ كابتن حمّودي")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.5))

                Text(motivationalMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(3)
            }

            Circle()
                .fill(GymTheme.beige.opacity(0.4))
                .frame(width: 40, height: 40)
                .overlay(
                    Text("🏋️")
                        .font(.system(size: 18))
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "F7F7F7"))
        )
    }

    // MARK: - End Project Button

    private var endProjectButton: some View {
        Button {
            showEndConfirmation = true
        } label: {
            HStack {
                Spacer()
                Text("🛑 إنهاء المشروع")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.red.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var motivationalMessage: String {
        if project.currentWeek <= 2 {
            return "بداية قوية! خلّك ملتزم بالخطة وبتشوف الفرق 💪"
        } else if project.progressFraction > 0.5 {
            return "نص الطريق وأنت ماشي صح! كمّل ولا تلتفت 🔥"
        } else {
            return "كل يوم تتمرن فيه هو خطوة للأمام. ثق بالعملية 🚀"
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && value < 100_000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
