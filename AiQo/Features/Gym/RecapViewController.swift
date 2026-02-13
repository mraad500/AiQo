import SwiftUI
import HealthKit
internal import Combine

// =========================
// File: Features/Gym/RecapView.swift
// SwiftUI - Workout History / Recap Screen
// =========================

// MARK: - Data Models
struct WorkoutHistorySection: Identifiable {
    let id = UUID()
    let dateTitle: String
    let items: [WorkoutHistoryItem]
}

struct WorkoutMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let tint: Color
}

struct WorkoutHistoryItem: Identifiable {
    let id = UUID()
    let title: String
    let source: String
    let duration: String
    let calories: String
    let icon: String
    let tint: Color

    // Detail fields
    let date: String
    let timeRange: String
    let location: String
    let intensity: String
    let device: String
    let workoutId: String
    let notes: String
    let metrics: [WorkoutMetric]
}

// MARK: - Recap View
struct RecapView: View {
    @StateObject private var viewModel = RecapViewModel()

    @State private var selectedItem: WorkoutHistoryItem?
    @State private var showSheet = false
    
    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    headerSection

                    if viewModel.isLoading && viewModel.sections.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    }

                    if !viewModel.sections.isEmpty {
                        ForEach(viewModel.sections) { section in
                            DatePillView(text: section.dateTitle)

                            ForEach(section.items) { item in
                                HistoryCardView(item: item) {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                        selectedItem = item
                                        showSheet = true
                                    }
                                }
                            }
                        }
                    } else if !viewModel.isLoading {
                        Text(L10n.t("gym.recap.empty"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.top, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .blur(radius: showSheet ? 6 : 0)
            .animation(.easeOut(duration: 0.18), value: showSheet)

            if showSheet {
                Color.black
                    .opacity(0.30)
                    .ignoresSafeArea()
                    .onTapGesture { closeSheet() }
                    .transition(.opacity)
            }

            if let item = selectedItem, showSheet {
                WorkoutDetailBottomSheet(
                    item: item,
                    initialRatio: 0.50,     // يبدأ 50%
                    autoExpandToFull: true, // وبعدين يكمل 100%
                    onClose: { closeSheet() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(5)
            }
        }
        .fontDesign(.rounded)
        .task { await viewModel.loadIfNeeded() }
    }

    private func closeSheet() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            showSheet = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if !showSheet { selectedItem = nil }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("recap.history.title", value: "History", comment: ""))
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.primary)

            Text(NSLocalizedString("recap.history.subtitle", value: "Your journey tracked via Apple Health.", comment: ""))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.top, 18)
        .padding(.horizontal, 4)
    }
}

// MARK: - Date Pill View
struct DatePillView: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground).opacity(0.78))
                        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
                )
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - History Card View
struct HistoryCardView: View {
    let item: WorkoutHistoryItem
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        ZStack {
            SoftGlassBackground(tint: item.tint, intensity: 0.42)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(item.tint.opacity(0.25))
                        .frame(width: 52, height: 52)

                    Image(systemName: item.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(item.tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)

                    Text(item.source)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.duration)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)

                    Text(item.calories)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            VStack {
                Spacer()
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.primary.opacity(0.08))

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(item.tint.opacity(0.85))
                            .frame(width: geometry.size.width * 0.72)
                    }
                }
                .frame(height: 10)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .frame(height: 104)
        .scaleEffect(x: 1.0, y: isPressed ? 0.94 : 1.0, anchor: .bottom)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isPressed)
        .onTapGesture {
            isPressed = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                onTap()
            }
        }
    }
}

// MARK: - Soft Glass Background
struct SoftGlassBackground: View {
    let tint: Color
    let intensity: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(tint.opacity(intensity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 10)
    }
}

// MARK: - Workout Detail Bottom Sheet (50% -> 100% "paper expand")
struct WorkoutDetailBottomSheet: View {
    let item: WorkoutHistoryItem
    let initialRatio: CGFloat
    let autoExpandToFull: Bool
    let onClose: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var currentRatio: CGFloat
    @State private var isExpanded: Bool = false

    init(item: WorkoutHistoryItem, initialRatio: CGFloat, autoExpandToFull: Bool, onClose: @escaping () -> Void) {
        self.item = item
        self.initialRatio = initialRatio
        self.autoExpandToFull = autoExpandToFull
        self.onClose = onClose
        _currentRatio = State(initialValue: initialRatio)
    }

    var body: some View {
        GeometryReader { geo in
            let fullH = geo.size.height
            let minH = max(320, fullH * initialRatio)
            let maxH = fullH * 0.98
            let sheetH = clamp(fullH * currentRatio, minH, maxH)
            let bottomSafe = geo.safeAreaInsets.bottom

            VStack(spacing: 0) {
                // Handle + Close
                HStack(spacing: 10) {
                    Capsule()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: 46, height: 5)
                        .padding(.leading, 12)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                toggleExpand(fullHeight: maxH, minHeight: minH, fullH: fullH)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(10)
                            .background(Circle().fill(Color.white.opacity(0.35)))
                    }
                    .padding(.trailing, 12)
                }
                .padding(.top, 10)
                .padding(.bottom, 8)

                WorkoutDetailContent(item: item, expanded: isExpanded)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: sheetH)
            .background(
                PaperGlassBackground(tint: item.tint, expanded: isExpanded)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, max(10, bottomSafe))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .offset(y: max(0, dragOffset))
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .global)
                    .onChanged { value in
                        let dy = value.translation.height

                        // سحب للأسفل = close feeling
                        if dy > 0 {
                            dragOffset = dy
                        } else {
                            // سحب للأعلى = expand feeling
                            dragOffset = 0
                            let pullUp = abs(dy)
                            let ratioBoost = (pullUp / fullH) * 0.8
                            currentRatio = clamp(currentRatio + ratioBoost, initialRatio, 0.98)
                        }
                    }
                    .onEnded { value in
                        let dy = value.translation.height
                        let vel = value.velocity.height

                        // close
                        let shouldClose = dy > 140 || vel > 950
                        if shouldClose {
                            onClose()
                            return
                        }

                        // settle expand/collapse
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                            dragOffset = 0

                            let threshold: CGFloat = 0.78
                            if currentRatio >= threshold {
                                currentRatio = 0.98
                                isExpanded = true
                            } else {
                                currentRatio = initialRatio
                                isExpanded = false
                            }
                        }
                    }
            )
            .onAppear {
                guard autoExpandToFull else { return }
                // يبدأ 50% ثم يتمدّد 100% مثل ورقة
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.spring(response: 0.46, dampingFraction: 0.92)) {
                        currentRatio = 0.98
                        isExpanded = true
                    }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }
            .onChange(of: item.id) {
                dragOffset = 0
                currentRatio = initialRatio
                isExpanded = false
                if autoExpandToFull {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        withAnimation(.spring(response: 0.46, dampingFraction: 0.92)) {
                            currentRatio = 0.98
                            isExpanded = true
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    private func toggleExpand(fullHeight: CGFloat, minHeight: CGFloat, fullH: CGFloat) {
        if isExpanded {
            currentRatio = initialRatio
            isExpanded = false
        } else {
            currentRatio = 0.98
            isExpanded = true
        }
    }

    private func clamp(_ v: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat { min(max(v, a), b) }
}




// MARK: - Paper Glass Background (Professional)
struct PaperGlassBackground: View {
    let tint: Color
    let expanded: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: expanded ? 40 : 34, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                // نظافة الكونتراست: خلي البياض خفيف جدًا
                RoundedRectangle(cornerRadius: expanded ? 40 : 34, style: .continuous)
                    .fill(Color.white.opacity(expanded ? 0.10 : 0.08))
            )
            .overlay(
                // Tint بسيط جدًا (مو مثل الصورة)
                RoundedRectangle(cornerRadius: expanded ? 40 : 34, style: .continuous)
                    .fill(tint.opacity(expanded ? 0.06 : 0.045))
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: expanded ? 40 : 34, style: .continuous)
                    .stroke(Color.white.opacity(expanded ? 0.22 : 0.18), lineWidth: 0.9)
            )
            .shadow(color: .black.opacity(expanded ? 0.22 : 0.16), radius: expanded ? 32 : 22, x: 0, y: -8)
    }
}

// MARK: - Workout Detail Content (Global layout)
struct WorkoutDetailContent: View {
    let item: WorkoutHistoryItem
    let expanded: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {

                header

                chips

                kpiRow

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredMetrics(item.metrics)) { metric in
                        WorkoutMetricCard(metric: metric)
                    }
                }

                SectionCard(title: "Session") {
                    KeyValueRow(title: "Date", value: item.date)
                    KeyValueRow(title: "Time", value: item.timeRange)
                    KeyValueRow(title: "Location", value: item.location)
                    KeyValueRow(title: "Intensity", value: item.intensity)
                }

                SectionCard(title: "Tracking") {
                    KeyValueRow(title: "Device", value: item.device)
                    KeyValueRow(title: "Source", value: item.source)
                    KeyValueRow(title: "Workout ID", value: shortId(item.workoutId))
                }

                if !item.notes.isEmpty {
                    SectionCard(title: "Notes") {
                        Text(item.notes)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack {
                    Text(L10n.t("gym.recap.swipe_close"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.70))
                    Spacer()
                }
                .padding(.top, 2)
            }
            .padding(.top, 6)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.tint.opacity(0.14))
                    .frame(width: 52, height: 52)

                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(item.tint)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("\(item.date) • \(item.timeRange)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    private var chips: some View {
        HStack(spacing: 8) {
            WorkoutTag(text: item.location, icon: "location.fill", tint: item.tint)
            WorkoutTag(text: item.intensity, icon: "bolt.fill", tint: item.tint)
            WorkoutTag(text: item.source, icon: "wave.3.right", tint: item.tint)
        }
        .padding(.top, 2)
    }

    private var kpiRow: some View {
        HStack(spacing: 10) {
            SummaryPill(title: "Duration", value: item.duration, icon: "timer", accent: item.tint)
            SummaryPill(title: "Calories", value: item.calories, icon: "flame.fill", accent: Color(red: 1.00, green: 0.65, blue: 0.20))

            // إذا ما تريدها، شيلها
            if let dist = item.metrics.first(where: { $0.title == L10n.t("gym.metric.distance") })?.value, dist != "--" {
                SummaryPill(title: "Distance", value: dist, icon: "figure.walk", accent: Color(red: 0.25, green: 0.85, blue: 0.70))
            }
        }
    }

    private func shortId(_ id: String) -> String {
        guard id.count > 12 else { return id }
        return "\(id.prefix(8))…\(id.suffix(4))"
    }

    // يمنع تكرار Duration/Calories إذا انضافت مرتين بالمصفوفة
    private func filteredMetrics(_ metrics: [WorkoutMetric]) -> [WorkoutMetric] {
        var seen = Set<String>()
        return metrics.filter { m in
            let key = "\(m.title)|\(m.icon)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }
}

// MARK: - Section Card (Glass, clean)
struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.secondary.opacity(0.85))
                .padding(.horizontal, 2)

            VStack(spacing: 8) {
                content
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
        )
    }
}

// MARK: - KeyValue Row (Global)
struct KeyValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
        )
    }
}

// MARK: - Summary Pill (KPIs)
struct SummaryPill: View {
    let title: String
    let value: String
    let icon: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        )
    }
}

// MARK: - Metric Card (Cleaner, global)
struct WorkoutMetricCard: View {
    let metric: WorkoutMetric

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(metric.tint.opacity(0.14))
                    .frame(width: 38, height: 38)

                Image(systemName: metric.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(metric.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(metric.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(metric.value)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        )
    }
}

// MARK: - Tag (Light, not noisy)
struct WorkoutTag: View {
    let text: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(tint)
            Text(text)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.primary.opacity(0.92))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.thinMaterial)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.14), lineWidth: 0.7)
        )
    }
}



// MARK: - View Model (HealthKit)
@MainActor
final class RecapViewModel: ObservableObject {
    @Published var sections: [WorkoutHistorySection] = []
    @Published var isLoading: Bool = false

    private var didLoad = false

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await loadWorkouts()
    }

    private func loadWorkouts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let workouts = try await HealthKitService.shared.fetchWorkouts(limit: 60)
            sections = WorkoutMapper.sections(from: workouts)
        } catch {
            sections = []
        }
    }
}

// MARK: - Workout Mapper
enum WorkoutMapper {
    static func sections(from workouts: [HKWorkout]) -> [WorkoutHistorySection] {
        guard !workouts.isEmpty else { return [] }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d MMM yyyy"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let grouped = Dictionary(grouping: workouts) { workout in
            dayFormatter.string(from: workout.startDate)
        }

        let sortedKeys = grouped.keys.sorted { keyA, keyB in
            let a = dayFormatter.date(from: keyA) ?? .distantPast
            let b = dayFormatter.date(from: keyB) ?? .distantPast
            return a > b
        }

        return sortedKeys.map { key in
            let items = (grouped[key] ?? [])
                .sorted { $0.startDate > $1.startDate }
                .map { workout in
                    mapWorkout(workout, dayFormatter: dayFormatter, timeFormatter: timeFormatter)
                }
            return WorkoutHistorySection(dateTitle: key, items: items)
        }
    }

    private static func mapWorkout(
        _ workout: HKWorkout,
        dayFormatter: DateFormatter,
        timeFormatter: DateFormatter
    ) -> WorkoutHistoryItem {
        let title = localizedWorkoutTitle(workout.workoutActivityType)
        let icon = workoutIcon(workout.workoutActivityType)
        let tint = workoutTint(workout.workoutActivityType)

        let start = workout.startDate
        let end = workout.endDate
        let timeRange = "\(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))"

        let duration = formatDuration(workout.duration)
        let kcal = energyBurned(from: workout)
        let distance = distanceMeters(from: workout)

        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)
        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)
        let hrStats = hrType.flatMap { workout.statistics(for: $0) }
        let stepsStats = stepsType.flatMap { workout.statistics(for: $0) }

        let avgHR = hrStats?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        let maxHR = hrStats?.maximumQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        let steps = stepsStats?.sumQuantity()?.doubleValue(for: .count())

        let pace = (distance ?? 0) > 0
            ? formatPace(seconds: workout.duration, meters: distance ?? 0)
            : nil

        let isIndoor = (workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool) ?? false

        let metrics: [WorkoutMetric] = [
            .init(title: L10n.t("gym.metric.duration"), value: duration, icon: "timer", tint: tint),
            .init(title: L10n.t("gym.metric.calories"), value: kcalString(kcal), icon: "flame.fill", tint: Color(red: 1.00, green: 0.65, blue: 0.20)),
            .init(title: L10n.t("gym.metric.distance"), value: distanceString(distance), icon: icon, tint: Color(red: 0.25, green: 0.85, blue: 0.70)),
            .init(title: L10n.t("gym.metric.avg_hr"), value: hrString(avgHR), icon: "heart.fill", tint: Color(red: 1.00, green: 0.40, blue: 0.55)),
            .init(title: L10n.t("gym.metric.max_hr"), value: hrString(maxHR), icon: "waveform.path.ecg", tint: Color(red: 0.95, green: 0.45, blue: 0.45)),
            .init(title: L10n.t("gym.metric.pace"), value: pace ?? "--", icon: "speedometer", tint: Color(red: 0.66, green: 0.58, blue: 0.98)),
            .init(title: L10n.t("gym.metric.steps"), value: stepsString(steps), icon: "shoeprints.fill", tint: Color(red: 0.72, green: 0.86, blue: 0.34)),
            .init(title: L10n.t("gym.metric.elevation"), value: "--", icon: "mountain.2.fill", tint: Color(red: 0.55, green: 0.45, blue: 0.95))
        ]

        return WorkoutHistoryItem(
            title: title,
            source: workout.sourceRevision.source.name,
            duration: duration,
            calories: kcalString(kcal),
            icon: icon,
            tint: tint,
            date: dayFormatter.string(from: start),
            timeRange: timeRange,
            location: isIndoor ? L10n.t("gym.recap.indoor") : L10n.t("gym.recap.outdoor"),
            intensity: L10n.t("gym.recap.intensity.moderate"),
            device: workout.device?.name ?? "Apple Watch",
            workoutId: workout.uuid.uuidString,
            notes: "",
            metrics: metrics
        )
    }

    private static func workoutTint(_ type: HKWorkoutActivityType) -> Color {
        switch type {
        case .running: return Color(red: 1.00, green: 0.78, blue: 0.45)
        case .walking: return Color(red: 0.25, green: 0.85, blue: 0.70)
        case .cycling: return Color(red: 1.00, green: 0.78, blue: 0.45)
        case .swimming: return Color(red: 0.25, green: 0.85, blue: 0.70)
        case .traditionalStrengthTraining, .functionalStrengthTraining: return Color(red: 1.00, green: 0.78, blue: 0.45)
        case .pilates: return Color(red: 0.66, green: 0.58, blue: 0.98)
        case .mindAndBody: return Color(red: 0.96, green: 0.50, blue: 0.62)
        case .elliptical, .stairClimbing, .jumpRope: return Color(red: 0.25, green: 0.85, blue: 0.70)
        case .soccer, .tennis, .basketball, .boxing, .martialArts: return Color(red: 1.00, green: 0.65, blue: 0.20)
        case .highIntensityIntervalTraining: return Color(red: 1.00, green: 0.65, blue: 0.20)
        case .yoga: return Color(red: 0.66, green: 0.58, blue: 0.98)
        default: return Color(red: 0.72, green: 0.86, blue: 0.34)
        }
    }

    private static func workoutIcon(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "dumbbell.fill"
        case .pilates: return "figure.core.training"
        case .mindAndBody: return "heart.text.square"
        case .elliptical: return "figure.elliptical"
        case .stairClimbing: return "figure.stair.stepper"
        case .soccer: return "soccerball"
        case .tennis: return "tennis.racket"
        case .basketball: return "basketball"
        case .boxing: return "figure.boxing"
        case .martialArts: return "figure.martial.arts"
        case .jumpRope: return "figure.jumprope"
        case .highIntensityIntervalTraining: return "flame.fill"
        case .yoga: return "figure.yoga"
        case .equestrianSports: return "figure.equestrian.sports"
        default: return "figure.mixed.cardio"
        }
    }

    private static func localizedWorkoutTitle(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return L10n.t("gym.exercise.running")
        case .walking: return L10n.t("gym.exercise.walking")
        case .cycling: return L10n.t("gym.exercise.cycling")
        case .swimming: return L10n.t("gym.exercise.swimming")
        case .traditionalStrengthTraining, .functionalStrengthTraining: return L10n.t("gym.exercise.strength")
        case .pilates: return L10n.t("gym.exercise.pilates")
        case .mindAndBody: return L10n.t("gym.exercise.gratitude")
        case .elliptical: return L10n.t("gym.exercise.elliptical")
        case .stairClimbing: return L10n.t("gym.exercise.stair_stepper")
        case .soccer: return L10n.t("gym.exercise.football")
        case .tennis: return L10n.t("gym.exercise.padel_tennis")
        case .basketball: return L10n.t("gym.exercise.basketball")
        case .boxing: return L10n.t("gym.exercise.boxing")
        case .martialArts: return L10n.t("gym.exercise.martial_arts")
        case .jumpRope: return L10n.t("gym.exercise.jump_rope")
        case .highIntensityIntervalTraining: return L10n.t("gym.exercise.hiit")
        case .yoga: return L10n.t("gym.exercise.yoga")
        case .equestrianSports: return L10n.t("gym.exercise.equestrian")
        default: return L10n.t("gym.exercise.other")
        }
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 { return String(format: "%02d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private static func formatPace(seconds: TimeInterval, meters: Double) -> String {
        guard meters > 0 else { return "--" }
        let paceSecPerKm = seconds / (meters / 1000.0)
        let m = Int(paceSecPerKm) / 60
        let s = Int(paceSecPerKm) % 60
        return String(format: "%d'%02d\"", m, s)
    }

    private static func kcalString(_ kcal: Double?) -> String {
        guard let kcal = kcal else { return "--" }
        return "\(Int(kcal)) kcal"
    }

    private static func distanceString(_ meters: Double?) -> String {
        guard let meters = meters else { return "--" }
        let km = meters / 1000.0
        return String(format: "%.2f km", km)
    }

    private static func hrString(_ bpm: Double?) -> String {
        guard let bpm = bpm else { return "--" }
        return "\(Int(bpm)) bpm"
    }

    private static func stepsString(_ steps: Double?) -> String {
        guard let steps = steps else { return "--" }
        return L10n.num(Int(steps))
    }

    private static func energyBurned(from workout: HKWorkout) -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let stats = workout.statistics(for: type),
              let qty = stats.sumQuantity() else {
            return nil
        }
        return qty.doubleValue(for: .kilocalorie())
    }

    private static func distanceMeters(from workout: HKWorkout) -> Double? {
        let distanceType: HKQuantityTypeIdentifier
        switch workout.workoutActivityType {
        case .cycling:
            distanceType = .distanceCycling
        default:
            distanceType = .distanceWalkingRunning
        }
        guard let type = HKQuantityType.quantityType(forIdentifier: distanceType),
              let stats = workout.statistics(for: type),
              let qty = stats.sumQuantity() else {
            return nil
        }
        return qty.doubleValue(for: .meter())
    }
}

// MARK: - Preview
#Preview {
    RecapView()
}
