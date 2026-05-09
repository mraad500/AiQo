import WidgetKit
import SwiftUI

@main
struct AiQoWidgetBundle: WidgetBundle {
    var body: some Widget {
        AiQoWidget()
        AiQoWatchFaceWidget()
        AiQoRingsFaceWidget()
#if os(iOS)
        HydrationWidget()
#endif
#if canImport(ActivityKit)
#if os(iOS)
        AiQoWidgetLiveActivity()
#endif
#endif
    }
}
