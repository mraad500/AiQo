#if DEBUG
import SwiftUI

struct DebugSleepVerificationView: View {
    @State private var session: UnifiedSleepSession = .makeEmpty()
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sleep Verification")
                    .font(.title.bold())

                if isLoading {
                    ProgressView()
                } else {
                    Group {
                        HStack {
                            Text("AiQo computed:")
                                .font(.headline)
                            Spacer()
                            Text("\(String(format: "%.2f", session.totalAsleepHours))h")
                                .font(.system(.title2, design: .monospaced).bold())
                        }

                        let hours = Int(session.totalAsleepSeconds / 3600)
                        let mins = Int((session.totalAsleepSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
                        Text("= \(hours)h \(mins)min (\(Int(session.totalAsleepSeconds))s)")
                            .font(.system(.body, design: .monospaced))

                        LabeledContent("Source", value: session.chosenSourceName)
                        LabeledContent("Bundle ID", value: session.chosenSourceBundleID)
                        LabeledContent("Session start", value: session.startDate.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Session end", value: session.endDate.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Stage count", value: "\(session.stages.count)")
                    }

                    Divider()

                    Text("Compare with Apple Health:")
                        .font(.headline)
                    Text("1. Open Health app")
                    Text("2. Browse > Sleep")
                    Text("3. Tap today > 'Show More Sleep Data'")
                    Text("4. Read 'Time Asleep' value")
                    Text("5. Should match within \u{00B1}1 min")

                    Divider()

                    Text("Stages:")
                        .font(.headline)
                    ForEach(session.stages) { stage in
                        HStack {
                            Text(stage.stage.rawValue)
                                .frame(width: 60, alignment: .leading)
                            Text("\(Int(stage.duration / 60))min")
                                .frame(width: 60, alignment: .trailing)
                            Text(stage.startDate.formatted(date: .omitted, time: .shortened))
                            Text("-")
                            Text(stage.endDate.formatted(date: .omitted, time: .shortened))
                        }
                        .font(.system(.caption, design: .monospaced))
                    }
                }
            }
            .padding()
        }
        .task {
            session = await SleepSessionProvider.shared.lastNightSession(forceRefresh: true)
            isLoading = false
        }
    }
}
#endif
