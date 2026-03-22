import SwiftUI

/// شاشة التقرير الأسبوعي — ملخص شامل لنشاط المستخدم مع مقارنة بالأسبوع الماضي
struct WeeklyReportView: View {
    @StateObject private var viewModel = WeeklyReportViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // السكور الإجمالي
                    if let data = viewModel.reportData {
                        overallScoreSection(data)
                    }

                    // شارت الخطوات اليومية
                    if let data = viewModel.reportData {
                        dailyChartSection(data)
                    }

                    // بطاقات الإحصائيات
                    metricsGridSection

                    // ملخص التمارين
                    if let data = viewModel.reportData, data.workoutCount > 0 {
                        workoutSummarySection(data)
                    }

                    // رسالة تحفيزية
                    if let data = viewModel.reportData {
                        motivationSection(data)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.97, blue: 0.95),
                        Color(red: 0.98, green: 0.96, blue: 0.93)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("تقرير الأسبوع")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            shareAsImage()
                        } label: {
                            Label("مشاركة كصورة", systemImage: "photo")
                        }

                        Button {
                            shareToInstagram()
                        } label: {
                            Label("Instagram Stories", systemImage: "camera.filters")
                        }

                        ShareLink(
                            item: shareText,
                            subject: Text("تقرير AiQo الأسبوعي"),
                            message: Text("شوف تقدمي هالأسبوع!")
                        ) {
                            Label("مشاركة نص", systemImage: "text.bubble")
                        }

                        Divider()

                        Button {
                            exportPDF()
                        } label: {
                            Label("تصدير PDF", systemImage: "doc.richtext")
                        }

                        Button {
                            exportCSV()
                        } label: {
                            Label("تصدير CSV", systemImage: "tablecells")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .task {
                await viewModel.loadReport()
            }
        }
    }

    // MARK: - Share Text

    private var shareText: String {
        guard let data = viewModel.reportData else { return "تقرير AiQo الأسبوعي" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let steps = formatter.string(from: NSNumber(value: data.totalSteps)) ?? "\(data.totalSteps)"
        return """
        📊 تقرير AiQo الأسبوعي
        🏃 \(steps) خطوة
        🔥 \(data.totalCalories) سعرة
        📏 \(String(format: "%.1f", data.totalDistanceKm)) كم
        😴 \(String(format: "%.1f", data.totalSleepHours)) ساعة نوم
        💪 \(data.workoutCount) تمرين
        ⭐️ النتيجة: \(data.overallScore)/100

        #AiQo #صحة #لياقة
        """
    }

    // MARK: - Share Actions

    private func shareAsImage() {
        guard let data = viewModel.reportData else { return }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        Task {
            guard let image = await ShareCardRenderer.renderWeeklyCard(
                steps: formatter.string(from: NSNumber(value: data.totalSteps)) ?? "\(data.totalSteps)",
                calories: formatter.string(from: NSNumber(value: data.totalCalories)) ?? "\(data.totalCalories)",
                distance: String(format: "%.1f", data.totalDistanceKm),
                sleep: String(format: "%.1f", data.totalSleepHours),
                workouts: data.workoutCount,
                score: data.overallScore,
                userName: UserProfileStore.shared.current.name
            ) else { return }

            ShareCardRenderer.presentShareSheet(image: image, text: shareText)
        }
    }

    private func shareToInstagram() {
        guard let data = viewModel.reportData else { return }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        Task {
            guard let image = await ShareCardRenderer.renderWeeklyCard(
                steps: formatter.string(from: NSNumber(value: data.totalSteps)) ?? "\(data.totalSteps)",
                calories: formatter.string(from: NSNumber(value: data.totalCalories)) ?? "\(data.totalCalories)",
                distance: String(format: "%.1f", data.totalDistanceKm),
                sleep: String(format: "%.1f", data.totalSleepHours),
                workouts: data.workoutCount,
                score: data.overallScore,
                userName: UserProfileStore.shared.current.name
            ) else { return }

            if !ShareCardRenderer.shareToInstagramStories(image: image) {
                // إذا Instagram مو منزّل، نفتح الـ share sheet العادي
                ShareCardRenderer.presentShareSheet(image: image, text: shareText)
            }
        }
    }

    // MARK: - Export Actions

    private func exportPDF() {
        guard let data = viewModel.reportData else { return }
        guard let url = HealthDataExporter.exportWeeklyPDF(
            data: data,
            userName: UserProfileStore.shared.current.name
        ) else { return }
        HealthDataExporter.share(url: url)
    }

    private func exportCSV() {
        guard let data = viewModel.reportData else { return }
        guard let url = HealthDataExporter.exportWeeklyCSV(data: data) else { return }
        HealthDataExporter.share(url: url)
    }

    // MARK: - Overall Score

    @ViewBuilder
    private func overallScoreSection(_ data: WeeklyReportData) -> some View {
        VStack(spacing: 16) {
            // التاريخ
            Text(weekRangeText(data))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // الحلقة
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 14)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: CGFloat(data.overallScore) / 100.0)
                    .stroke(
                        scoreGradient(data.overallScore),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.7), value: data.overallScore)

                VStack(spacing: 2) {
                    Text("\(data.overallScore)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())

                    Text("من 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(scoreEmoji(data.overallScore))
                .font(.title2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("نتيجة الأسبوع \(data.overallScore) من 100، \(scoreEmoji(data.overallScore))")
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Daily Chart

    @ViewBuilder
    private func dailyChartSection(_ data: WeeklyReportData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("الخطوات اليومية")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<data.dailySteps.count, id: \.self) { index in
                    VStack(spacing: 4) {
                        let maxVal = max(data.dailySteps.max() ?? 1, 1)
                        let height = CGFloat(data.dailySteps[index]) / CGFloat(maxVal) * 100

                        Text(abbreviateNumber(data.dailySteps[index]))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.77, green: 0.94, blue: 0.86),
                                        Color(red: 0.6, green: 0.85, blue: 0.73)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: max(height, 4))
                            .animation(.spring(response: 0.6).delay(Double(index) * 0.05), value: data.dailySteps)

                        Text(dayLabel(index, from: data.weekStartDate))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 140)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Metrics Grid

    @ViewBuilder
    private var metricsGridSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(viewModel.metrics) { metric in
                ReportMetricCard(metric: metric)
            }
        }
    }

    // MARK: - Workout Summary

    @ViewBuilder
    private func workoutSummarySection(_ data: WeeklyReportData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("ملخص التمارين", systemImage: "flame.fill")
                .font(.headline)

            HStack(spacing: 20) {
                workoutStatItem(
                    value: "\(data.workoutCount)",
                    label: "تمرين",
                    icon: "figure.strengthtraining.traditional"
                )

                workoutStatItem(
                    value: "\(data.totalWorkoutMinutes)",
                    label: "دقيقة",
                    icon: "clock.fill"
                )

                workoutStatItem(
                    value: String(format: "%.0f", Double(data.totalWorkoutMinutes) / Double(max(data.workoutCount, 1))),
                    label: "معدل / تمرين",
                    icon: "chart.bar.fill"
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    @ViewBuilder
    private func workoutStatItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color(red: 0.97, green: 0.84, blue: 0.64))

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Motivation

    @ViewBuilder
    private func motivationSection(_ data: WeeklyReportData) -> some View {
        let message = motivationMessage(score: data.overallScore)

        VStack(spacing: 8) {
            Text(message.emoji)
                .font(.largeTitle)

            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Loading

    @ViewBuilder
    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("جاري تحضير التقرير...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private func weekRangeText(_ data: WeeklyReportData) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: data.weekStartDate)) - \(formatter.string(from: data.weekEndDate))"
    }

    private func dayLabel(_ index: Int, from startDate: Date) -> String {
        let date = Calendar.current.date(byAdding: .day, value: index, to: startDate)!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateFormat = "EEE"
        let label = formatter.string(from: date)
        // أول حرفين بس
        return String(label.prefix(2))
    }

    private func abbreviateNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fk", Double(number) / 1000.0)
        }
        return "\(number)"
    }

    private func scoreGradient(_ score: Int) -> LinearGradient {
        if score >= 75 {
            return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        } else if score >= 50 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        }
    }

    private func scoreEmoji(_ score: Int) -> String {
        if score >= 90 { return "أسطوري! 🏆" }
        if score >= 75 { return "ممتاز! 💪" }
        if score >= 50 { return "جيد، كمّل! 🔥" }
        if score >= 25 { return "ابدأ الأسبوع القادم أقوى 💫" }
        return "الأسبوع القادم أحسن إن شاء الله 🌱"
    }

    private func motivationMessage(score: Int) -> (emoji: String, text: String) {
        if score >= 90 {
            return ("🏆", "أسبوع أسطوري! أنت وحش يا بطل. خلّي هالزخم مستمر.")
        } else if score >= 75 {
            return ("💪", "أسبوع ممتاز! شغلك واضح. شوي وتوصل القمة.")
        } else if score >= 50 {
            return ("🔥", "أسبوع جيد! عندك أساس قوي. زيد شوي بالتمارين والنوم.")
        } else if score >= 25 {
            return ("💫", "بداية حلوة! كل خطوة تقربك لهدفك. الأسبوع الجاي بيكون أحسن.")
        } else {
            return ("🌱", "كل أسبوع فرصة جديدة. ابدأ بأشياء بسيطة وبتشوف الفرق.")
        }
    }
}

// MARK: - Report Metric Card

struct ReportMetricCard: View {
    let metric: ReportMetricItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // الأيقونة والعنوان
            HStack {
                Image(systemName: metric.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tintColor.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(tintColor.opacity(0.15))
                    .clipShape(Circle())

                Text(metric.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // القيمة
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(metric.value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                Text(metric.unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // نسبة التغيير
            if metric.changePercent != 0 {
                changeIndicator
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tintColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tintColor.opacity(0.15), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = "\(metric.title)، \(metric.value) \(metric.unit)"
        if metric.changePercent > 0 {
            text += "، زاد \(String(format: "%.0f", metric.changePercent)) بالمية عن الأسبوع الماضي"
        } else if metric.changePercent < 0 {
            text += "، نقص \(String(format: "%.0f", abs(metric.changePercent))) بالمية عن الأسبوع الماضي"
        }
        return text
    }

    @ViewBuilder
    private var changeIndicator: some View {
        let isPositive = metric.changePercent > 0
        let color: Color = isPositive ? .green : .red
        let arrow = isPositive ? "arrow.up.right" : "arrow.down.right"

        HStack(spacing: 4) {
            Image(systemName: arrow)
                .font(.system(size: 10, weight: .bold))

            Text(String(format: "%.0f%%", abs(metric.changePercent)))
                .font(.system(size: 11, weight: .semibold, design: .rounded))

            Text("عن الأسبوع الماضي")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(color)
    }

    private var tintColor: Color {
        let c = metric.tint.color
        return Color(red: c.r, green: c.g, blue: c.b)
    }
}

// MARK: - Preview

#Preview {
    WeeklyReportView()
}
