import SwiftUI
import UIKit

struct DailyAuraView: View {
    @StateObject private var viewModel: DailyAuraViewModel
    @State private var isSheetPresented = false
    @State private var centerBreath = false
    @State private var didFireCompletionHaptic = false
    @State private var displayedProgress: Double = 0
    @State private var displayedStepsProgress: Double = 0
    @State private var displayedCaloriesProgress: Double = 0

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: DailyAuraViewModel())
    }

    @MainActor
    init(viewModel: DailyAuraViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Button {
            isSheetPresented = true
        } label: {
            VStack(spacing: 4) {
                auraGraphic
                    .frame(width: 172, height: 172)

                Text(viewModel.progressPercentText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task {
            await viewModel.onAppear()
        }
        .sheet(isPresented: $isSheetPresented) {
            DailyGoalsSheetView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: viewModel.auraProgress) { oldValue, newValue in
            withAnimation(.easeInOut(duration: 1.2)) {
                displayedProgress = newValue
            }

            if newValue >= 1, oldValue < 1, !didFireCompletionHaptic {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                didFireCompletionHaptic = true
            }
            if newValue < 1 {
                didFireCompletionHaptic = false
            }
        }
        .onChange(of: viewModel.stepsProgress) { _, newValue in
            withAnimation(.easeInOut(duration: 1.2)) {
                displayedStepsProgress = newValue
            }
        }
        .onChange(of: viewModel.caloriesProgress) { _, newValue in
            withAnimation(.easeInOut(duration: 1.2)) {
                displayedCaloriesProgress = newValue
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                centerBreath.toggle()
            }
            displayedProgress = 0
            displayedStepsProgress = 0
            displayedCaloriesProgress = 0
            withAnimation(.easeInOut(duration: 1.2)) {
                displayedProgress = viewModel.auraProgress
                displayedStepsProgress = viewModel.stepsProgress
                displayedCaloriesProgress = viewModel.caloriesProgress
            }
        }
    }

    private var auraGraphic: some View {
        let beige = Color(red: 0.91, green: 0.79, blue: 0.59)
        let mint = Color(red: 0.64, green: 0.86, blue: 0.81)

        return ZStack {
            ForEach(DailyAuraVector.segments) { segment in
                AuraArcShape(
                    radiusRatio: segment.radiusRatio,
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle
                )
                .stroke(
                    segmentBaseColor(segment, beige: beige, mint: mint),
                    style: StrokeStyle(
                        lineWidth: segment.lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }

            ForEach(DailyAuraVector.segments) { segment in
                AuraArcShape(
                    radiusRatio: segment.radiusRatio,
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle
                )
                    .trim(from: 0, to: segmentReveal(for: segment, progress: progressForSegment(segment)))
                    .stroke(
                        segmentActiveColor(segment, beige: beige, mint: mint),
                        style: StrokeStyle(
                            lineWidth: segment.lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .animation(
                        .easeInOut(duration: 1.2)
                            .delay(segmentActivationDelay(for: segment)),
                        value: progressForSegment(segment)
                    )
            }

            Circle()
                .fill(Color(red: 0.72, green: 0.90, blue: 0.86).opacity(0.26))
                .frame(width: 12, height: 12)
                .scaleEffect(centerBreath ? 1.006 : 0.994)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: centerBreath)

            Circle()
                .stroke(Color(red: 0.62, green: 0.87, blue: 0.81).opacity(0.58), lineWidth: 3)
                .frame(width: 20, height: 20)
                .scaleEffect(centerBreath ? 1.006 : 0.994)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: centerBreath)

            if viewModel.auraProgress >= 1 {
                Circle()
                    .stroke(Color.orange.opacity(0.24), lineWidth: 10)
                    .frame(width: 178, height: 178)
                    .blur(radius: 3)
                    .transition(.opacity)
            }
        }
    }

    private func progressForSegment(_ segment: AuraVectorSegment) -> Double {
        segment.isGreenGroup ? displayedStepsProgress : displayedCaloriesProgress
    }

    private func segmentReveal(for segment: AuraVectorSegment, progress: Double) -> CGFloat {
        let stageStart = segment.threshold - 0.25
        let stageProgress = min(max((progress - stageStart) / 0.25, 0), 1)
        let smoothedStage = stageProgress * stageProgress * (3 - 2 * stageProgress) // smoothstep
        let orderedProgress = (smoothedStage * Double(segment.bucketSize)) - Double(segment.bucketOrder)
        return CGFloat(min(max(orderedProgress, 0), 1))
    }

    private func segmentActivationDelay(for segment: AuraVectorSegment) -> Double {
        let bucketDelay = Double(segment.bucketIndex) * 0.04
        let orderDelay = Double(segment.bucketOrder) * 0.007
        return min(bucketDelay + orderDelay, 0.24)
    }

    private func segmentBaseColor(_ segment: AuraVectorSegment, beige: Color, mint: Color) -> Color {
        segment.isGreenGroup ? mint.opacity(0.30) : beige.opacity(0.35)
    }

    private func segmentActiveColor(_ segment: AuraVectorSegment, beige: Color, mint: Color) -> Color {
        segment.isGreenGroup ? mint.opacity(1.0) : beige.opacity(1.0)
    }

    func ingest(todaySteps: Int, todayCalories: Double) {
        viewModel.ingest(todaySteps: todaySteps, todayCalories: todayCalories)
    }
}

private struct AuraArcShape: Shape {
    let radiusRatio: CGFloat
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = size * radiusRatio
        let start = Angle.degrees(startAngle - 90)
        let end = Angle.degrees(normalizedEndAngle - 90)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: start,
            endAngle: end,
            clockwise: false
        )
        return path
    }

    private var normalizedEndAngle: Double {
        endAngle < startAngle ? endAngle + 360 : endAngle
    }
}

private struct AuraVectorSegment: Identifiable {
    let id = UUID()
    let radiusRatio: CGFloat
    let startAngle: Double
    let endAngle: Double
    let lineWidth: CGFloat
    let order: Int
    let threshold: Double
    let bucketIndex: Int
    let bucketOrder: Int
    let bucketSize: Int
    let isGreenGroup: Bool
}

private enum DailyAuraVector {
    static let segments: [AuraVectorSegment] = {
        let defs: [AuraSegmentDefinition] = [
            .init(radiusRatio: 0.14, startAngle: 208, endAngle: 244, lineWidth: 3.2, stage: 0, isGreenGroup: true),
            .init(radiusRatio: 0.14, startAngle: 262, endAngle: 301, lineWidth: 3.2, stage: 0, isGreenGroup: true),
            .init(radiusRatio: 0.14, startAngle: 334, endAngle: 24, lineWidth: 3.2, stage: 0, isGreenGroup: true),
            .init(radiusRatio: 0.14, startAngle: 45, endAngle: 86, lineWidth: 3.2, stage: 0, isGreenGroup: true),
            .init(radiusRatio: 0.14, startAngle: 112, endAngle: 154, lineWidth: 3.2, stage: 0, isGreenGroup: true),
            .init(radiusRatio: 0.14, startAngle: 174, endAngle: 195, lineWidth: 3.2, stage: 0, isGreenGroup: true),

            .init(radiusRatio: 0.21, startAngle: 196, endAngle: 252, lineWidth: 3.6, stage: 1, isGreenGroup: true),
            .init(radiusRatio: 0.21, startAngle: 272, endAngle: 324, lineWidth: 3.6, stage: 1, isGreenGroup: true),
            .init(radiusRatio: 0.21, startAngle: 352, endAngle: 26, lineWidth: 3.6, stage: 1, isGreenGroup: true),
            .init(radiusRatio: 0.21, startAngle: 66, endAngle: 125, lineWidth: 3.6, stage: 1, isGreenGroup: true),
            .init(radiusRatio: 0.21, startAngle: 146, endAngle: 170, lineWidth: 3.6, stage: 1, isGreenGroup: true),

            .init(radiusRatio: 0.29, startAngle: 182, endAngle: 350, lineWidth: 4.2, stage: 2, isGreenGroup: true),
            .init(radiusRatio: 0.29, startAngle: 20, endAngle: 112, lineWidth: 4.2, stage: 2, isGreenGroup: true),

            .init(radiusRatio: 0.36, startAngle: 212, endAngle: 9, lineWidth: 5, stage: 2, isGreenGroup: true),
            .init(radiusRatio: 0.36, startAngle: 36, endAngle: 164, lineWidth: 5, stage: 2, isGreenGroup: true),

            .init(radiusRatio: 0.43, startAngle: 150, endAngle: 231, lineWidth: 6.5, stage: 3, isGreenGroup: false),
            .init(radiusRatio: 0.43, startAngle: 283, endAngle: 72, lineWidth: 6.5, stage: 3, isGreenGroup: false),
            .init(radiusRatio: 0.52, startAngle: 32, endAngle: 126, lineWidth: 6.5, stage: 3, isGreenGroup: false),
            .init(radiusRatio: 0.52, startAngle: 166, endAngle: 320, lineWidth: 6.5, stage: 3, isGreenGroup: false),
        ]

        var bucketSizes = [0, 0, 0, 0]
        for def in defs {
            bucketSizes[def.stage] += 1
        }
        var bucketOffsets = [0, 0, 0, 0]

        return defs.enumerated().map { idx, def in
            let bucketOrder = bucketOffsets[def.stage]
            bucketOffsets[def.stage] += 1

            return AuraVectorSegment(
                radiusRatio: def.radiusRatio,
                startAngle: def.startAngle,
                endAngle: def.endAngle,
                lineWidth: def.lineWidth,
                order: idx,
                threshold: Double(def.stage + 1) * 0.25,
                bucketIndex: def.stage,
                bucketOrder: bucketOrder,
                bucketSize: max(bucketSizes[def.stage], 1),
                isGreenGroup: def.isGreenGroup
            )
        }
    }()
}

private struct AuraSegmentDefinition {
    let radiusRatio: CGFloat
    let startAngle: Double
    let endAngle: Double
    let lineWidth: CGFloat
    let stage: Int
    let isGreenGroup: Bool
}

private struct DailyGoalsSheetView: View {
    @ObservedObject var viewModel: DailyAuraViewModel
    @State private var selectedTab: DailyGoalsTab = .goals

    enum DailyGoalsTab: String, CaseIterable, Identifiable {
        case goals = "Goals"
        case history = "History"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Daily Goals", selection: $selectedTab) {
                    ForEach(DailyGoalsTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                if selectedTab == .goals {
                    goalsTab
                } else {
                    historyTab
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle("Daily Goals")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var goalsTab: some View {
        VStack(spacing: 12) {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Stepper(value: Binding(
                        get: { viewModel.goals.steps },
                        set: { viewModel.updateStepsGoal($0) }
                    ), in: 1000...50000, step: 500) {
                        HStack {
                            Text("Steps Goal")
                            Spacer()
                            Text("\(viewModel.goals.steps)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: Binding(
                        get: { Int(viewModel.goals.activeCalories.rounded()) },
                        set: { viewModel.updateCaloriesGoal($0) }
                    ), in: 100...5000, step: 50) {
                        HStack {
                            Text("Calories Goal")
                            Spacer()
                            Text("\(Int(viewModel.goals.activeCalories.rounded()))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today")
                        .font(.headline)
                    Text("Steps: \(viewModel.stepsToday)")
                    Text("Calories: \(Int(viewModel.caloriesToday.rounded())) kcal")
                    Text("Aura Progress: \(viewModel.progressPercentText)")
                        .fontWeight(.semibold)

                    ProgressView(value: viewModel.auraProgress)
                        .tint(.orange)
                }
            }
        }
    }

    private var historyTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(viewModel.last14Days) { record in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.displayDate(for: record.dateKey))
                                .font(.subheadline.weight(.semibold))
                            Text("\(record.steps) steps  •  \(Int(record.calories.rounded())) kcal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        MiniProgressRing(progress: viewModel.progress(for: record))
                            .frame(width: 24, height: 24)

                        Text("\(Int((viewModel.progress(for: record) * 100).rounded()))%")
                            .font(.caption.weight(.semibold))
                            .frame(width: 38, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

private struct MiniProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

#Preview {
    DailyAuraView(viewModel: DailyAuraViewModel(provider: MockActivityProvider()))
}
