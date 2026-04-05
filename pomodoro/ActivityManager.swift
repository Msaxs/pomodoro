import Foundation
#if os(iOS)
import ActivityKit

final class ActivityManager {
    static let shared = ActivityManager()
    private init() {}

    func endAllActivities() async {
        for activity in Activity<PomodoroAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    func terminateAllNow() {
        let activities = Activity<PomodoroAttributes>.activities
        for activity in activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
#endif
