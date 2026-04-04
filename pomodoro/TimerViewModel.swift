import SwiftUI
import Combine
#if os(iOS)
import ActivityKit
#endif

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

    /// Premium dashboard label for Dynamic Island
    var islandLabel: String {
        switch self {
        case .ready: "PRIMING 01/05"
        case .work1: "CONQUERING 02/05"
        case .rest1: "IDLE 03/05"
        case .work2: "CONQUERING 04/05"
        case .rest2: "IDLE 05/05"
        }
    }

    var colorHex: String {
        switch self {
        case .ready: "#FFA500"
        case .work1, .work2: "#B31A1A"
        case .rest1: "#99E699"
        case .rest2: "#33B366"
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
    private var lastLiveActivityUpdate: Date = .distantPast
    #if os(iOS)
    private var liveActivity: Activity<PomodoroAttributes>?
    #endif

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
        startOrUpdateLiveActivity()
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
        updateLiveActivity(force: true)
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
        } else if isCompressing {
            updateLiveActivity()
        }
    }

    private func advanceStage() {
        hapticMedium()
        currentStage = currentStage.next
        timeRemaining = currentStage.duration
        stageEndDate = Date().addingTimeInterval(currentStage.duration)
        updateLiveActivity(force: true)
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
        updateLiveActivity(force: true)
    }

    // MARK: - Live Activity

    #if os(iOS)
    private func liveActivityState() -> PomodoroAttributes.ContentState {
        let expiry = stageEndDate ?? Date().addingTimeInterval(timeRemaining)
        return .init(
            stageName: currentStage.islandLabel,
            stageColorHex: currentStage.colorHex,
            timeRemaining: timeRemaining,
            totalDuration: currentStage.duration,
            expiryDate: expiry,
            isPaused: !isRunning
        )
    }
    #endif

    private func startOrUpdateLiveActivity() {
        #if os(iOS)
        if liveActivity != nil {
            updateLiveActivity()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = PomodoroAttributes()
        let state = liveActivityState()
        liveActivity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil)
        )
        #endif
    }

    private func updateLiveActivity(force: Bool = false) {
        #if os(iOS)
        guard let activity = liveActivity else { return }
        // Throttle to every 0.5s during normal ticks; always push on force (stage change, pause, etc.)
        let now = Date()
        guard force || now.timeIntervalSince(lastLiveActivityUpdate) >= 0.5 else { return }
        lastLiveActivityUpdate = now
        let state = liveActivityState()
        Task {
            await activity.update(.init(state: state, staleDate: state.expiryDate))
        }
        #endif
    }

    func endLiveActivity() {
        #if os(iOS)
        guard let activity = liveActivity else { return }
        let state = liveActivityState()
        Task {
            await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
        }
        liveActivity = nil
        #endif
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
        // Subtle double-tap feel — professional, not jarring
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred(intensity: 0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            gen.impactOccurred(intensity: 0.4)
        }
        #endif
    }
}
