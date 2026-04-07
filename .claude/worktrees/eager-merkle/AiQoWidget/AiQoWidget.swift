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
        .supportedFamilies(supportedFamilies)

        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }

    private var supportedFamilies: [WidgetFamily] {
#if os(iOS)
        [
            .systemSmall,
            .systemMedium,
            .systemLarge
        ]
#elseif os(watchOS)
        [
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ]
#else
        []
#endif
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
