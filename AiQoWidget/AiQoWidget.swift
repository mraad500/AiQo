import WidgetKit
import SwiftUI

struct AiQoWidget: Widget {
    let kind: String = "AiQoWidget"

    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: kind, provider: AiQoProvider()) { entry in
            AiQoWidgetView(entry: entry)
                .widgetContainerBackground()
        }
        .configurationDisplayName("AiQo Daily Progress")
        .description("Steps, calories, and goal progress.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])

        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

private extension View {
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { Color.clear }
        } else {
            self
        }
    }
}
