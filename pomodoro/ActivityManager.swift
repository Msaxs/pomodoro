import Foundation
#if os(iOS)
import ActivityKit

/// Centralized cleanup — kills every live PomodoroAttributes activity unconditionally.
/// Used on terminate and force-background so the Island never outlives the app.
final class ActivityManager {
    static let shared = ActivityManager()
    private init() {}

    func endAllActivities() {
        Task {
            for activity in Activity<PomodoroAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
#endif
