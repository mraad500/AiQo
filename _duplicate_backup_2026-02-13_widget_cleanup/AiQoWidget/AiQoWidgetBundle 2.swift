import WidgetKit
import SwiftUI

@main
struct AiQoWidgetBundle: WidgetBundle {
    var body: some Widget {
        AiQoWidget()
        AiQoWatchFaceWidget()
        AiQoRingsFaceWidget()
        AiQoWidgetLiveActivity()
    }
}
