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
    }

    enum WorkoutPhase: String, Codable, Hashable {
        case running
        case paused
        case ending
    }

    var workoutID: String
    var startedAt: Date
}

struct AiQoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(context.state.title.uppercased(), systemImage: "figure.run")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.mint)
                    Spacer()
                    Text(context.state.phase == .paused ? "PAUSED" : "LIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Text(elapsedString(context.state.elapsedSeconds))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                HStack(spacing: 18) {
                    metric("heart.fill", "\(max(0, context.state.heartRate))", "BPM")
                    metric("flame.fill", "\(max(0, context.state.activeCalories))", "KCAL")
                    metric("figure.run", String(format: "%.2f", max(0, context.state.distanceMeters) / 1000), "KM")
                }
            }
            .padding(14)
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(.mint)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.mint)
                        Text("\(max(0, context.state.heartRate))")
                            .font(.headline.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(elapsedString(context.state.elapsedSeconds))
                        .font(.headline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        Text(context.state.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.mint)
                        Text("\(max(0, context.state.activeCalories)) kcal")
                            .font(.caption.monospacedDigit())
                        Text(String(format: "%.2f km", max(0, context.state.distanceMeters) / 1000))
                            .font(.caption.monospacedDigit())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.mint)
                    Text("\(max(0, context.state.heartRate))")
                        .monospacedDigit()
                }
                .font(.caption2)
            } compactTrailing: {
                Text(elapsedString(context.state.elapsedSeconds))
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "figure.run")
                    .foregroundStyle(.mint)
            }
            .keylineTint(.mint)
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

    @ViewBuilder
    private func metric(_ icon: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(.mint)
                Text(unit)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}

extension WorkoutActivityAttributes {
    fileprivate static var preview: WorkoutActivityAttributes {
        WorkoutActivityAttributes(workoutID: UUID().uuidString, startedAt: .now)
    }
}

extension WorkoutActivityAttributes.ContentState {
    fileprivate static var running: WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            title: "Running",
            elapsedSeconds: 63,
            heartRate: 104,
            activeCalories: 1,
            distanceMeters: 0,
            phase: .running
        )
    }

    fileprivate static var paused: WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            title: "Running",
            elapsedSeconds: 145,
            heartRate: 108,
            activeCalories: 12,
            distanceMeters: 230,
            phase: .paused
        )
    }
}

#Preview("Workout Live Activity", as: .content, using: WorkoutActivityAttributes.preview) {
   AiQoWidgetLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.running
    WorkoutActivityAttributes.ContentState.paused
}
