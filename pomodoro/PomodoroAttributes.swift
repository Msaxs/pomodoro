import Foundation
#if canImport(ActivityKit)
import ActivityKit

public struct PomodoroAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        var title: String
        var totalSeconds: Double
        var sessionCount: Int
        var isPaused: Bool
        var currentTaskID: String
        var startTime: Date
    }
}
#endif
