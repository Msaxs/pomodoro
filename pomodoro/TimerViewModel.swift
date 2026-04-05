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
        case .ready: "PREPARING"
        case .work1, .work2: "DOMINATING"
        case .rest1, .rest2: "RECOVERING"
        }
    }

    /// Premium dashboard label for Dynamic Island
    var islandLabel: String {
        switch self {
        case .ready: "PRIMING 01/05"
        case .work1: "DOMINATING 02/05"
        case .rest1: "RECOVERING 03/05"
        case .work2: "DOMINATING 04/05"
        case .rest2: "RECOVERING 05/05"
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
    @Published var compressionMultiplier: Double = 1.0

    private var timer: AnyCancellable?
    private var stageEndDate: Date?
    private var pausedRemaining: TimeInterval?
    private var backgroundDate: Date?
    private var compressionStartDate: Date?
    private var lastVirtualSecond: Int = Int.max
    private var lastLiveActivityUpdate: Date = .distantPast
    #if os(iOS)
    private var liveActivity: Activity<PomodoroAttributes>?
    #endif

    init() {
        #if os(iOS)
        if let existing = Activity<PomodoroAttributes>.activities.first {
            liveActivity = existing
        }
        #endif
    }

    // MARK: - Gesture Handlers

    func togglePlayPause() {
        hapticHeavy()
        if isRunning {
            pause()
        } else {
            play()
        }
    }

    func startCompression() {
        guard isRunning else { return }
        hapticWarning()
        isCompressing = true
        compressionStartDate = Date()
        lastVirtualSecond = Int(timeRemaining)
    }

    func stopCompression() {
        isCompressing = false
        compressionMultiplier = 1.0
        compressionStartDate = nil
    }

    // MARK: - Scene Phase

    func sceneDidEnterBackground() {
        // Island stays alive in background — update it with latest state
        updateLiveActivity(force: true)
        guard isRunning else { return }
        backgroundDate = Date()
    }

    func sceneDidEnterForeground() {
        // Re-adopt if our reference was lost (e.g. after a crash restart)
        #if os(iOS)
        if liveActivity == nil {
            liveActivity = Activity<PomodoroAttributes>.activities.first
        }
        #endif

        guard isRunning, let bg = backgroundDate else {
            // Not running — just refresh the Island state
            updateLiveActivity(force: true)
            return
        }
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

        if isCompressing, let startDate = compressionStartDate {
            // Dual-stage piecewise exponential (elapsed from 0.5s trigger):
            // Stage 1 (0–1.5s): 1x → 120x  using 120^(t/1.5)
            // Stage 2 (1.5–2.5s): 120x → 240x  using 120 * 2^((t-1.5)/1.0)
            // Continuous and smooth at the 120x boundary.
            let elapsed = Date().timeIntervalSince(startDate)
            if elapsed <= 1.5 {
                compressionMultiplier = pow(120.0, elapsed / 1.5)
            } else {
                let t2 = min((elapsed - 1.5) / 1.0, 1.0)
                compressionMultiplier = 120.0 * pow(2.0, t2)
            }
            stageEndDate = end.addingTimeInterval(-0.1 * (compressionMultiplier - 1))
        }

        let remaining = max(0, (stageEndDate ?? end).timeIntervalSince(Date()))

        // 1:1 haptic sync — one .soft tap per virtual second skipped.
        // .soft is the lightest UIKit style, distinct from the .heavy single-tap.
        // 120x max → up to 12 skipped seconds per 0.1s tick, well within Taptic Engine limits.
        if isCompressing {
            let currentSecond = Int(remaining)
            let skipped = max(0, lastVirtualSecond - currentSecond)
            for _ in 0..<skipped { hapticSoft() }
            lastVirtualSecond = currentSecond
        }

        timeRemaining = remaining

        if remaining <= 0 {
            advanceStage()
        } else if isCompressing {
            updateLiveActivity()
        }
    }

    private func advanceStage() {
        hapticMedium()
        isCompressing = false
        compressionMultiplier = 1.0
        compressionStartDate = nil
        lastVirtualSecond = Int.max
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
        // If we have a valid reference, just update it
        if liveActivity != nil {
            updateLiveActivity(force: true)
            return
        }
        // Try to adopt an existing activity (e.g. from a previous session)
        if let existing = Activity<PomodoroAttributes>.activities.first {
            liveActivity = existing
            updateLiveActivity(force: true)
            return
        }
        // No existing activity — create a fresh one
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

    private func hapticSoft() {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.impactOccurred()
        #endif
    }

    private func hapticHeavy() {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: .heavy)
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
