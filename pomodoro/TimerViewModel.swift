import SwiftUI
import Combine

enum PomodoroStage: CaseIterable {
    case ready, work1, rest1, work2, rest2

    var duration: TimeInterval {
        switch self {
        case .ready: 150
        case .work1: 1500
        case .rest1: 150
        case .work2: 1500
        case .rest2: 300
        }
    }

    var backgroundColor: Color {
        switch self {
        case .ready: Color.orange
        case .work1, .work2: Color(red: 0.7, green: 0.1, blue: 0.1)
        case .rest1: Color(red: 0.6, green: 0.9, blue: 0.6)
        case .rest2: Color(red: 0.2, green: 0.7, blue: 0.4)
        }
    }

    var label: String {
        switch self {
        case .ready: "Ready"
        case .work1: "Work 1"
        case .rest1: "Rest 1"
        case .work2: "Work 2"
        case .rest2: "Rest 2"
        }
    }

    var next: PomodoroStage {
        let all = PomodoroStage.allCases
        let idx = all.firstIndex(of: self)!
        return all[(idx + 1) % all.count]
    }
}

@MainActor
final class TimerViewModel: ObservableObject {
    @Published var currentStage: PomodoroStage = .ready
    @Published var timeRemaining: TimeInterval = PomodoroStage.ready.duration
    @Published var isRunning = false
    @Published var isCompressing = false

    private var timer: AnyCancellable?
    private var stageEndDate: Date?
    private var pausedRemaining: TimeInterval?
    private var backgroundDate: Date?

    // MARK: - Gesture Handlers

    func togglePlayPause() {
        hapticLight()
        if isRunning {
            pause()
        } else {
            play()
        }
    }

    func startCompression() {
        hapticWarning()
        isCompressing = true
    }

    func stopCompression() {
        isCompressing = false
    }

    // MARK: - Scene Phase

    func sceneDidEnterBackground() {
        guard isRunning else { return }
        backgroundDate = Date()
    }

    func sceneDidEnterForeground() {
        guard isRunning, let bg = backgroundDate else { return }
        backgroundDate = nil
        let elapsed = Date().timeIntervalSince(bg)
        fastForward(elapsed)
    }

    // MARK: - Timer Core

    private func play() {
        isRunning = true
        let remaining = pausedRemaining ?? timeRemaining
        stageEndDate = Date().addingTimeInterval(remaining)
        pausedRemaining = nil
        startTicker()
    }

    private func pause() {
        isRunning = false
        timer?.cancel()
        timer = nil
        if let end = stageEndDate {
            pausedRemaining = max(0, end.timeIntervalSince(Date()))
            timeRemaining = pausedRemaining!
        }
        stageEndDate = nil
    }

    private func startTicker() {
        timer?.cancel()
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func tick() {
        guard let end = stageEndDate else { return }

        let speedMultiplier: TimeInterval = isCompressing ? 60.0 : 1.0

        if isCompressing {
            // When compressing, consume extra time from the deadline
            stageEndDate = end.addingTimeInterval(-0.1 * (speedMultiplier - 1))
        }

        let remaining = max(0, (stageEndDate ?? end).timeIntervalSince(Date()))
        timeRemaining = remaining

        if remaining <= 0 {
            advanceStage()
        }
    }

    private func advanceStage() {
        hapticMedium()
        currentStage = currentStage.next
        timeRemaining = currentStage.duration
        stageEndDate = Date().addingTimeInterval(currentStage.duration)
    }

    private func fastForward(_ elapsed: TimeInterval) {
        var remaining = elapsed
        var stage = currentStage
        var stageTime = max(0, (stageEndDate ?? Date()).timeIntervalSince(Date().addingTimeInterval(-elapsed) ))

        // Recalculate from what was left before background
        stageTime = timeRemaining

        while remaining >= stageTime {
            remaining -= stageTime
            stage = stage.next
            stageTime = stage.duration
        }

        currentStage = stage
        timeRemaining = stageTime - remaining
        stageEndDate = Date().addingTimeInterval(timeRemaining)
    }

    // MARK: - Haptics

    private func hapticLight() {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        #endif
    }

    private func hapticMedium() {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        #endif
    }

    private func hapticWarning() {
        #if os(iOS)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
        #endif
    }
}
