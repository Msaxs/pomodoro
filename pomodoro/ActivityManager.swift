import Foundation
#if os(iOS)
import ActivityKit

/// Centralized cleanup — kills every live PomodoroAttributes activity unconditionally.
final class ActivityManager {
    static let shared = ActivityManager()
    private init() {}

    /// Async cleanup — safe for normal foreground/background transitions.
    func endAllActivities() async {
        for activity in Activity<PomodoroAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Synchronous last-resort for applicationWillTerminate.
    /// Fires end signals then blocks the thread so the OS can deliver them
    /// before the process is torn down.
    func terminateAllNow() {
        let semaphore = DispatchSemaphore(value: 0)
        let activities = Activity<PomodoroAttributes>.activities
        guard !activities.isEmpty else { return }
        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            semaphore.signal()
        }
        // Wait up to 0.5s for the async work to finish
        _ = semaphore.wait(timeout: .now() + 0.5)
    }
}
#endif
