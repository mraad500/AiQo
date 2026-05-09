import SwiftUI
import HealthKit
import Combine

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

    var isDisplayable: Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "--"
    }
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
    let startTime: String?
    let endTime: String?
    let timeRange: String?
    let location: String?
    let device: String?
    let workoutId: String
    let notes: String?
    let metrics: [WorkoutMetric]
}

// MARK: - Recap View
struct RecapView: View {
    @StateObject private var viewModel = RecapViewModel()

    @State private var selectedItem: WorkoutHistoryItem?
    @State private var selectedDetent: PresentationDetent = .fraction(0.5)
    var onScrollOffsetChange: ((CGFloat) -> Void)? = nil

    private let railScrollOffsetSpaceName = "RecapRailScroll"
    
    var body: some View {
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
                                selectedDetent = .fraction(0.5)
                                selectedItem = item
                            }
                        }
                    }
                } else if !viewModel.isLoading {
                    Text(L10n.t("gym.recap.empty"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
            .background(alignment: .top) {
                RailScrollOffsetReader(coordinateSpaceName: railScrollOffsetSpaceName)
            }
        }
        .coordinateSpace(name: railScrollOffsetSpaceName)
        .onPreferenceChange(RailScrollOffsetPreferenceKey.self) { offset in
            onScrollOffsetChange?(offset)
        }
        .fontDesign(.rounded)
        .task { await viewModel.loadIfNeeded() }
        .sheet(item: $selectedItem) { item in
            WorkoutDetailSheetView(item: item)
                .presentationDetents([.fraction(0.5), .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
                .presentationCornerRadius(34)
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("recap.history.title", value: "History", comment: ""))
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(.primary)

            Text(NSLocalizedString("recap.history.subtitle", value: "Your journey tracked via Apple Health.", comment: ""))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "1A1A1A"))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color(hex: "F5F5F5"))
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
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "E8F7F0"), Color(hex: "D4F0E3")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(item.tint.opacity(0.25))
                        .frame(width: 52, height: 52)

                    Image(systemName: item.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(item.tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(item.source)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.duration)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(item.calories)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
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
        .environment(\.colorScheme, .light)
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

// MARK: - Native Workout Detail Sheet
struct WorkoutDetailSheetView: View {
    let item: WorkoutHistoryItem

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var orderedMetrics: [WorkoutMetric] {
        let preferredTitles = [
            L10n.t("gym.metric.duration"),
            L10n.t("gym.metric.calories"),
            L10n.t("gym.metric.distance"),
            L10n.t("gym.metric.avg_hr"),
            L10n.t("gym.metric.max_hr"),
            L10n.t("gym.metric.pace"),
            L10n.t("gym.metric.steps")
        ]

        let available = filteredMetrics(item.metrics).filter(\.isDisplayable)
        let prioritized = preferredTitles.compactMap { title in
            available.first(where: { $0.title == title })
        }
        let prioritizedTitles = Set(prioritized.map(\.title))

        return prioritized + available.filter { !prioritizedTitles.contains($0.title) }
    }

    private var headerMetaText: String? {
        [
            nonEmpty(item.date),
            nonEmpty(item.timeRange)
        ]
        .compactMap { $0 }
        .joined(separator: " • ")
        .nilIfEmpty
    }

    private var sessionRows: [WorkoutDetailRowModel] {
        [
            WorkoutDetailRowModel(title: L10n.t("recap.info.date"), value: nonEmpty(item.date)),
            WorkoutDetailRowModel(title: L10n.t("recap.info.start_time"), value: nonEmpty(item.startTime)),
            WorkoutDetailRowModel(title: L10n.t("recap.info.end_time"), value: nonEmpty(item.endTime)),
            WorkoutDetailRowModel(title: L10n.t("recap.info.location"), value: nonEmpty(item.location))
        ]
        .compactMap { $0 }
    }

    private var trackingRows: [WorkoutDetailRowModel] {
        [
            WorkoutDetailRowModel(title: L10n.t("recap.info.source"), value: nonEmpty(item.source)),
            WorkoutDetailRowModel(title: L10n.t("recap.info.device"), value: nonEmpty(item.device)),
            WorkoutDetailRowModel(title: L10n.t("recap.info.workout_id"), value: shortId(item.workoutId))
        ]
        .compactMap { $0 }
    }

    var body: some View {
        ZStack(alignment: .top) {
            WorkoutSheetSurface(tint: item.tint)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if !orderedMetrics.isEmpty {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(orderedMetrics) { metric in
                                WorkoutMetricCard(metric: metric)
                            }
                        }
                    }

                    if !sessionRows.isEmpty {
                        SectionCard(title: L10n.t("recap.section.session")) {
                            ForEach(sessionRows) { row in
                                KeyValueRow(title: row.title, value: row.value)
                            }
                        }
                    }

                    if !trackingRows.isEmpty {
                        SectionCard(title: L10n.t("recap.section.tracking")) {
                            ForEach(trackingRows) { row in
                                KeyValueRow(title: row.title, value: row.value)
                            }
                        }
                    }

                    if let notes = nonEmpty(item.notes) {
                        SectionCard(title: L10n.t("recap.section.notes")) {
                            Text(notes)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 36)
            }
        }
        .background(Color.clear)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(item.tint.opacity(0.18))
                    .frame(width: 58, height: 58)

                Image(systemName: item.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(item.tint)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let headerMetaText {
                    Text(headerMetaText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            if let source = nonEmpty(item.source) {
                WorkoutSourceBadge(text: source, tint: item.tint)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    item.tint.opacity(0.14),
                                    Color.white.opacity(0.07)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
        )
    }

    private func shortId(_ id: String) -> String {
        guard id.count > 12 else { return id }
        return "\(id.prefix(8))…\(id.suffix(4))"
    }

    private func filteredMetrics(_ metrics: [WorkoutMetric]) -> [WorkoutMetric] {
        var seen = Set<String>()
        return metrics.filter { metric in
            let key = "\(metric.title)|\(metric.icon)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              trimmed != "--" else {
            return nil
        }
        return trimmed
    }
}

private struct WorkoutDetailRowModel: Identifiable {
    let id = UUID()
    let title: String
    let value: String

    init?(title: String, value: String?) {
        guard let value else { return nil }
        self.title = title
        self.value = value
    }
}

struct WorkoutSheetSurface: View {
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                tint.opacity(0.10),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.9)
            )
            .shadow(color: .black.opacity(0.18), radius: 28, x: 0, y: -8)
    }
}

// MARK: - Section Card (Glass, clean)
struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary.opacity(0.85))
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
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.primary)
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
                    .foregroundStyle(metric.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(metric.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(metric.value)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.primary)
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

struct WorkoutSourceBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary.opacity(0.92))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
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

        let indoorValue = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool

        let metrics: [WorkoutMetric] = [
            .init(title: L10n.t("gym.metric.duration"), value: duration, icon: "timer", tint: tint),
            .init(title: L10n.t("gym.metric.calories"), value: kcalString(kcal), icon: "flame.fill", tint: Color(red: 1.00, green: 0.65, blue: 0.20)),
            .init(title: L10n.t("gym.metric.distance"), value: distanceString(distance), icon: icon, tint: Color(red: 0.25, green: 0.85, blue: 0.70)),
            .init(title: L10n.t("gym.metric.avg_hr"), value: hrString(avgHR), icon: "heart.fill", tint: Color(red: 1.00, green: 0.40, blue: 0.55)),
            .init(title: L10n.t("gym.metric.max_hr"), value: hrString(maxHR), icon: "waveform.path.ecg", tint: Color(red: 0.95, green: 0.45, blue: 0.45)),
            .init(title: L10n.t("gym.metric.pace"), value: pace ?? "--", icon: "speedometer", tint: Color(red: 0.66, green: 0.58, blue: 0.98)),
            .init(title: L10n.t("gym.metric.steps"), value: stepsString(steps), icon: "shoeprints.fill", tint: Color(red: 0.72, green: 0.86, blue: 0.34))
        ]

        return WorkoutHistoryItem(
            title: title,
            source: workout.sourceRevision.source.name,
            duration: duration,
            calories: kcalString(kcal),
            icon: icon,
            tint: tint,
            date: dayFormatter.string(from: start),
            startTime: timeFormatter.string(from: start),
            endTime: timeFormatter.string(from: end),
            timeRange: timeRange,
            location: indoorValue.map { $0 ? L10n.t("gym.recap.indoor") : L10n.t("gym.recap.outdoor") },
            device: workout.device?.name,
            workoutId: workout.uuid.uuidString,
            notes: nil,
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
        if let totalDistance = workout.totalDistance {
            return totalDistance.doubleValue(for: .meter())
        }

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
