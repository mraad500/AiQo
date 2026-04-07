import WidgetKit
import SwiftUI

@main
struct AiQoWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        AiQoWatchWidget()
        AiQoWeeklyWidget()
    }
}
