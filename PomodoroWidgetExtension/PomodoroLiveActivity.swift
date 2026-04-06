import ActivityKit
import SwiftUI
import WidgetKit

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroAttributes.self) { context in
            // Lock Screen — bare minimum
            Text(context.state.title)
                .foregroundStyle(.white)
                .padding()
                .background(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.title)
                        .foregroundStyle(.white)
                }
            } compactLeading: {
                Text("🟡")
            } compactTrailing: {
                Text(formatted(context.state.totalSeconds))
                    .foregroundStyle(.white)
            } minimal: {
                Text("🟡")
            }
        }
    }

    private func formatted(_ time: Double) -> String {
        let t = Int(ceil(max(0, time)))
        return String(format: "%02d:%02d", t / 60, t % 60)
    }
}
