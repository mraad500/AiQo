//
//  AiQoWidgetLiveActivity.swift
//  AiQoWidget
//
//  Created by Mohammed Raad on 07/02/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var elapsedSeconds: Int
        var heartRate: Int
        var activeCalories: Int
        var distanceMeters: Double
        var phase: WorkoutPhase
        var heartRateState: HeartRateState
        var activeBuffs: [Buff]

        var isZone2Active: Bool {
            heartRateState == .zone2
        }
    }

    enum WorkoutPhase: String, Codable, Hashable {
        case running
        case paused
        case ending
    }

    enum HeartRateState: String, Codable, Hashable {
        case neutral
        case warmingUp
        case zone2
        case belowZone2
        case aboveZone2
    }

    struct Buff: Codable, Hashable, Identifiable {
        var id: String
        var label: String
        var systemImage: String
        var tone: BuffTone

        init(id: String, label: String, systemImage: String, tone: BuffTone) {
            self.id = id
            self.label = label
            self.systemImage = systemImage
            self.tone = tone
        }
    }

    enum BuffTone: String, Codable, Hashable {
        case mint
        case amber
        case sky
        case rose
        case lavender
    }

    var workoutID: String
    var startedAt: Date
}

struct AiQoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(.black.opacity(0.76))
                .activitySystemActionForegroundColor(context.state.accentTint)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedHeartModule(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterModule(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTimerModule(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomModule(state: context.state)
                }
            } compactLeading: {
                CompactLeadingModule(state: context.state)
            } compactTrailing: {
                CompactTrailingModule(state: context.state)
            } minimal: {
                MinimalModule(state: context.state)
            }
            .keylineTint(context.state.keylineTint)
        }
    }
}

private struct LiveActivityLockScreenView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Label(state.title.uppercased(), systemImage: state.phase.activitySymbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(state.isZone2Active ? state.accentTint : .mint)
                    .lineLimit(1)

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    if state.isZone2Active {
                        Zone2Badge(state: state)
                    }

                    if !state.activeBuffs.isEmpty {
                        BuffRail(buffs: state.activeBuffs, compact: true)
                    }

                    Text(state.phase.lockScreenLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.82))
                }
            }

            Text(elapsedString(state.elapsedSeconds))
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            HStack(alignment: .top, spacing: 26) {
                LockScreenMetric(
                    icon: "heart.fill",
                    value: "\(max(0, state.heartRate))",
                    unit: "BPM",
                    tint: state.accentTint
                )
                LockScreenMetric(
                    icon: "flame.fill",
                    value: "\(max(0, state.activeCalories))",
                    unit: "KCAL",
                    tint: .orange.opacity(0.9)
                )
                LockScreenMetric(
                    icon: "figure.run",
                    value: String(format: "%.2f", max(0, state.distanceMeters) / 1000),
                    unit: "KM",
                    tint: .white.opacity(0.78)
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.86),
                            state.glowTint.opacity(state.isZone2Active ? 0.18 : 0.08),
                            .black.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }
        }
    }
}

private struct ExpandedHeartModule: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 10) {
            PulseHeartGlyph(state: state, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(max(0, state.heartRate))")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text(state.heartRateState.shortLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
    }
}

private struct ExpandedCenterModule: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 6) {
            Text(state.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)

            if state.activeBuffs.isEmpty {
                Text(state.phase.liveLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))
            } else {
                BuffRail(buffs: state.activeBuffs, compact: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExpandedTimerModule: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(elapsedString(state.elapsedSeconds))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(state.phase.liveLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

private struct ExpandedBottomModule: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 10) {
            MetricChip(
                icon: "flame.fill",
                value: "\(max(0, state.activeCalories))",
                unit: "KCAL",
                tint: .orange.opacity(0.9)
            )
            MetricChip(
                icon: "figure.run",
                value: String(format: "%.2f", max(0, state.distanceMeters) / 1000),
                unit: "KM",
                tint: .white.opacity(0.76)
            )
            if !state.activeBuffs.isEmpty {
                BuffSummaryChip(buffs: state.activeBuffs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CompactLeadingModule: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PulseHeartGlyph(state: state, size: 22)

            if !state.activeBuffs.isEmpty {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.82))
                    Text("\(state.activeBuffs.count)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 12, height: 12)
                .overlay {
                    Circle().stroke(.white.opacity(0.12), lineWidth: 0.5)
                }
                .offset(x: 4, y: -4)
            }
        }
    }
}

private struct CompactTrailingModule: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        Text(elapsedString(state.elapsedSeconds))
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.92))
            .contentTransition(.numericText())
    }
}

private struct MinimalModule: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PulseHeartGlyph(state: state, size: 22)

            if !state.activeBuffs.isEmpty {
                Circle()
                    .fill(state.activeBuffs[0].tone.color)
                    .frame(width: 7, height: 7)
                    .overlay {
                        Circle().stroke(.black.opacity(0.38), lineWidth: 1)
                    }
                    .offset(x: 2, y: 2)
            }
        }
    }
}

private struct Zone2Badge: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.glowTint)
                .frame(width: 7, height: 7)
                .shadow(color: state.glowTint.opacity(0.75), radius: 4)

            Text("ZONE 2")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.92))

            Image(systemName: "waveform.path.ecg")
                .font(.caption2.weight(.bold))
                .foregroundStyle(state.accentTint)
                .symbolEffect(.pulse.byLayer, isActive: state.isZone2Active)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(state.accentTint.opacity(0.55), lineWidth: 1)
                }
        }
    }
}

private struct LockScreenMetric: View {
    let icon: String
    let value: String
    let unit: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }

            Text(value)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PulseHeartGlyph: View {
    let state: WorkoutActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(state.glowTint.opacity(state.isZone2Active ? 0.26 : 0.13))
                .frame(width: size, height: size)
                .shadow(
                    color: state.isZone2Active ? state.glowTint.opacity(0.58) : .clear,
                    radius: state.isZone2Active ? size * 0.30 : 0
                )

            Circle()
                .stroke(.white.opacity(0.10), lineWidth: 1)
                .frame(width: size, height: size)

            Image(systemName: state.heartRateState.symbolName)
                .font(.system(size: size * 0.40, weight: .semibold))
                .foregroundStyle(state.accentTint)
                .symbolEffect(.pulse.byLayer, isActive: state.isZone2Active)
        }
    }
}

private struct MetricChip: View {
    let icon: String
    let value: String
    let unit: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.60))
            }

            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
        }
    }
}

private struct BuffRail: View {
    let buffs: [WorkoutActivityAttributes.Buff]
    let compact: Bool

    private var visibleBuffs: [WorkoutActivityAttributes.Buff] {
        Array(buffs.prefix(compact ? 2 : 3))
    }

    private var overflowCount: Int {
        max(0, buffs.count - visibleBuffs.count)
    }

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            ForEach(visibleBuffs) { buff in
                BuffGlyph(buff: buff, compact: compact)
            }

            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, compact ? 5 : 8)
                    .padding(.vertical, compact ? 4 : 6)
                    .background {
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.08))
                    }
            }
        }
    }
}

private struct BuffGlyph: View {
    let buff: WorkoutActivityAttributes.Buff
    let compact: Bool

    var body: some View {
        Image(systemName: buff.systemImage)
            .font(.system(size: compact ? 10 : 11, weight: .semibold))
            .foregroundStyle(buff.tone.color)
            .frame(width: compact ? 20 : 24, height: compact ? 20 : 24)
            .background {
                Circle()
                    .fill(.white.opacity(0.08))
                    .overlay {
                        Circle().stroke(buff.tone.color.opacity(0.28), lineWidth: 0.8)
                    }
            }
            .accessibilityLabel(buff.label)
    }
}

private struct BuffSummaryChip: View {
    let buffs: [WorkoutActivityAttributes.Buff]

    var body: some View {
        HStack(spacing: 8) {
            BuffRail(buffs: buffs, compact: true)
            Text("Buffs")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.76))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
        }
    }
}

private extension WorkoutActivityAttributes.ContentState {
    var accentTint: Color {
        heartRateState.accentTint
    }

    var glowTint: Color {
        heartRateState.glowTint
    }

    var keylineTint: Color {
        isZone2Active ? glowTint.opacity(0.92) : .white.opacity(0.70)
    }
}

private extension WorkoutActivityAttributes.HeartRateState {
    var displayLabel: String {
        switch self {
        case .neutral:
            return "Steady"
        case .warmingUp:
            return "Warmup"
        case .zone2:
            return "Zone 2"
        case .belowZone2:
            return "Lift Pace"
        case .aboveZone2:
            return "Ease Pace"
        }
    }

    var shortLabel: String {
        switch self {
        case .neutral:
            return "steady"
        case .warmingUp:
            return "warmup"
        case .zone2:
            return "zone 2"
        case .belowZone2:
            return "below"
        case .aboveZone2:
            return "above"
        }
    }

    var symbolName: String {
        switch self {
        case .neutral:
            return "heart.fill"
        case .warmingUp:
            return "sun.max.fill"
        case .zone2:
            return "waveform.path.ecg"
        case .belowZone2:
            return "arrow.down.heart.fill"
        case .aboveZone2:
            return "arrow.up.heart.fill"
        }
    }

    var accentTint: Color {
        switch self {
        case .neutral:
            return .white.opacity(0.82)
        case .warmingUp:
            return Color(red: 0.96, green: 0.82, blue: 0.58)
        case .zone2:
            return Color(red: 0.71, green: 0.93, blue: 0.86)
        case .belowZone2:
            return Color(red: 0.72, green: 0.86, blue: 0.98)
        case .aboveZone2:
            return Color(red: 0.98, green: 0.76, blue: 0.78)
        }
    }

    var glowTint: Color {
        switch self {
        case .neutral:
            return .white
        case .warmingUp:
            return Color(red: 0.93, green: 0.74, blue: 0.43)
        case .zone2:
            return Color(red: 0.54, green: 0.87, blue: 0.78)
        case .belowZone2:
            return Color(red: 0.58, green: 0.78, blue: 0.96)
        case .aboveZone2:
            return Color(red: 0.93, green: 0.60, blue: 0.64)
        }
    }
}

private extension WorkoutActivityAttributes.BuffTone {
    var color: Color {
        switch self {
        case .mint:
            return Color(red: 0.71, green: 0.93, blue: 0.86)
        case .amber:
            return Color(red: 0.95, green: 0.80, blue: 0.58)
        case .sky:
            return Color(red: 0.72, green: 0.86, blue: 0.98)
        case .rose:
            return Color(red: 0.98, green: 0.76, blue: 0.78)
        case .lavender:
            return Color(red: 0.84, green: 0.78, blue: 0.98)
        }
    }
}

private extension WorkoutActivityAttributes.WorkoutPhase {
    var liveLabel: String {
        switch self {
        case .running:
            return "Live"
        case .paused:
            return "Paused"
        case .ending:
            return "Closing"
        }
    }

    var lockScreenLabel: String {
        liveLabel.uppercased()
    }

    var activitySymbolName: String {
        switch self {
        case .running:
            return "figure.run"
        case .paused:
            return "pause.fill"
        case .ending:
            return "flag.checkered"
        }
    }
}

private func elapsedString(_ seconds: Int) -> String {
    let total = max(0, seconds)
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%02d:%02d", minutes, secs)
}

extension WorkoutActivityAttributes {
    fileprivate static var preview: WorkoutActivityAttributes {
        WorkoutActivityAttributes(workoutID: UUID().uuidString, startedAt: .now)
    }
}

extension WorkoutActivityAttributes.ContentState {
    fileprivate static var running: WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            title: "Zone 2 Run",
            elapsedSeconds: 1286,
            heartRate: 132,
            activeCalories: 286,
            distanceMeters: 4210,
            phase: .running,
            heartRateState: .zone2,
            activeBuffs: [
                .init(id: "hydration", label: "Hydration", systemImage: "drop.fill", tone: .sky),
                .init(id: "focus", label: "Focus", systemImage: "sparkles", tone: .lavender)
            ]
        )
    }

    fileprivate static var paused: WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            title: "Zone 2 Run",
            elapsedSeconds: 1450,
            heartRate: 118,
            activeCalories: 304,
            distanceMeters: 4520,
            phase: .paused,
            heartRateState: .warmingUp,
            activeBuffs: [
                .init(id: "recovery", label: "Recovery", systemImage: "leaf.fill", tone: .mint)
            ]
        )
    }
}

#Preview("Workout Live Activity", as: .content, using: WorkoutActivityAttributes.preview) {
    AiQoWidgetLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.running
    WorkoutActivityAttributes.ContentState.paused
}
