import Foundation
#if os(iOS)
import ActivityKit

struct PomodoroAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var stageName: String
        var stageColorHex: String
        var timeRemaining: Double
        var totalDuration: Double
        var expiryDate: Date
        var isPaused: Bool
    }
}
#endif
