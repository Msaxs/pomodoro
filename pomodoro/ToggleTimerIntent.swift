import AppIntents
import Foundation

struct ToggleTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Toggle Timer"
    static var description: IntentDescription = "Pauses or resumes the Pomodoro timer."

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .toggleTimerIntent, object: nil)
        }
        return .result()
    }
}

extension Notification.Name {
    static let toggleTimerIntent = Notification.Name("com.pomodoro.toggleTimer")
}
