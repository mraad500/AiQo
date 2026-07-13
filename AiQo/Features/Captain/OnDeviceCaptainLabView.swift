import SwiftUI
import UIKit

#if DEBUG
/// DEBUG-only test bench for the free on-device Captain.
/// Reached from Developer Panel → Brain → "مختبر حمودي على الجهاز".
/// Runs a fixed set of realistic Iraqi prompts through both on-device strategies
/// (Direct vs English-bridge) so quality can be judged by reading, not assuming.
struct OnDeviceCaptainLabView: View {

    struct Row: Identifiable {
        let id = UUID()
        let prompt: String
        var direct: String?
        var directError: String?
        var english: String?
        var iraqi: String?
        var bridgeError: String?
        var directMs: Int?
        var bridgeMs: Int?
        var running = false
    }

    @State private var rows: [Row]
    @State private var availability = "…"
    @State private var isBusy = false

    private let lab = OnDeviceCaptainLab()

    init() {
        _rows = State(initialValue: Self.prompts.map { Row(prompt: $0) })
    }

    var body: some View {
        List {
            Section {
                Text(availability)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await runAll() }
                } label: {
                    Label(isBusy ? "كاعد يشتغل…" : "شغّل الكل", systemImage: "play.fill")
                }
                .disabled(isBusy)

                Button {
                    UIPasteboard.general.string = exportText()
                } label: {
                    Label("انسخ كل النتائج", systemImage: "doc.on.doc")
                }
            } footer: {
                Text("كله على الجهاز — صفر إنترنت، صفر كلاود. شغّل الكل، اقرا الردود، وكلّي أيهم يحس حمودي أكثر.")
            }

            ForEach($rows) { $row in
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.prompt)
                            .font(.headline)
                            .environment(\.layoutDirection, .rightToLeft)
                        Spacer()
                        if row.running {
                            ProgressView()
                        } else {
                            Button {
                                Task { await run(id: row.id) }
                            } label: {
                                Image(systemName: "play.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    resultBlock(
                        label: "أ) مباشر (المحرّك الحالي)",
                        text: row.direct,
                        error: row.directError,
                        ms: row.directMs,
                        tint: .blue
                    )

                    resultBlock(
                        label: "ب) عبر الإنكليزي + لهجة",
                        text: row.iraqi,
                        error: row.bridgeError,
                        ms: row.bridgeMs,
                        tint: .green
                    )

                    if let english = row.english, !english.isEmpty {
                        DisclosureGroup("النص الإنكليزي الوسطي") {
                            Text(english)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("مختبر حمودي على الجهاز")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            availability = lab.availabilityDescription()
        }
    }

    @ViewBuilder
    private func resultBlock(label: String, text: String?, error: String?, ms: Int?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(tint)
                Spacer()
                if let ms {
                    Text("\(ms)ms")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if let error {
                Text("✕ \(error)")
                    .font(.callout)
                    .foregroundStyle(.red)
            } else if let text, !text.isEmpty {
                Text(text)
                    .font(.body)
                    .environment(\.layoutDirection, .rightToLeft)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .textSelection(.enabled)
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    @MainActor
    private func run(id: UUID) async {
        guard let idx = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[idx].running = true
        let prompt = rows[idx].prompt

        let out = await lab.run(prompt: prompt)

        guard let target = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[target].direct = out.direct
        rows[target].directError = out.directError
        rows[target].english = out.englishCore
        rows[target].iraqi = out.iraqiBridge
        rows[target].bridgeError = out.bridgeError
        rows[target].directMs = out.directMs
        rows[target].bridgeMs = out.bridgeMs
        rows[target].running = false
    }

    @MainActor
    private func runAll() async {
        isBusy = true
        for row in rows {
            await run(id: row.id)
        }
        isBusy = false
    }

    private func exportText() -> String {
        var lines: [String] = ["AiQo — On-Device Captain Lab", availability, ""]
        for (i, row) in rows.enumerated() {
            lines.append("[\(i + 1)] \(row.prompt)")
            lines.append("A/direct (\(row.directMs ?? 0)ms): \(row.directError.map { "ERROR " + $0 } ?? row.direct ?? "-")")
            lines.append("B/bridge (\(row.bridgeMs ?? 0)ms): \(row.bridgeError.map { "ERROR " + $0 } ?? row.iraqi ?? "-")")
            if let english = row.english, !english.isEmpty {
                lines.append("   en: \(english)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static let prompts: [String] = [
        "هلاو شلونك",
        "شنو هو تطبيق ايكو؟",
        "تعبان اليوم وما عندي مزاج اتمرن",
        "شكد لازم امشي بل يوم؟",
        "اكلت برغر وندمت، شسوي؟",
        "ما اكدر انام بالليل",
        "اريد اخس عشر كيلو",
        "شلون ابني عضلات وانا مبتدئ",
        "ظهري يوجعني بعد التمرين",
        "عطني نصيحة تحفزني"
    ]
}

#Preview {
    NavigationStack {
        OnDeviceCaptainLabView()
    }
}
#endif
