import SwiftUI
import Combine
#if os(iOS)
import ActivityKit
import UIKit
#endif

enum PomodoroStage: CaseIterable, Sendable {
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

    var islandLabel: String {
        switch self {
        case .ready: "PREPARING 01/05"
        case .work1: "DOMINATING 02/05"
        case .rest1: "RECOVERING 03/05"
        case .work2: "DOMINATING 04/05"
        case .rest2: "RECOVERING 05/05"
        }
    }

    var next: PomodoroStage {
        let all = PomodoroStage.allCases
        let idx = all.firstIndex(of: self)!
        return all[(idx + 1) % all.count]
    }
}

final class TimerViewModel: ObservableObject {
    @Published var currentStage: PomodoroStage = .ready
    @Published var timeRemaining: TimeInterval = PomodoroStage.ready.duration
    @Published var isRunning = false
    @Published var isCompressing = false
    @Published var compressionMultiplier: Double = 1.0

    private var intentObserver: AnyCancellable?
    private var timer: AnyCancellable?
    private var stageEndDate: Date?
    private var pausedRemaining: TimeInterval?
    private var backgroundDate: Date?
    private var compressionStartDate: Date?
    private var lastVirtualSecond: Int = Int.max
    private var lastLiveActivityUpdate: Date = .distantPast
    #if os(iOS)
    private var liveActivityID: String?
    #endif

    init() {
        #if os(iOS)
        liveActivityID = Activity<PomodoroAttributes>.activities.first?.id
        #endif
        intentObserver = NotificationCenter.default
            .publisher(for: .toggleTimerIntent)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.toggleFromIntent() }
    }

    // MARK: - Gesture Handlers

    func togglePlayPause() {
        hapticHeavy()
        if isRunning { pause() } else { play() }
    }

    func toggleFromIntent() {
        if isRunning { pause() } else { play() }
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
        pushLiveActivityUpdate(force: true)
        guard isRunning else { return }
        backgroundDate = Date()
    }

    func sceneDidEnterForeground() {
        #if os(iOS)
        if liveActivityID == nil {
            liveActivityID = Activity<PomodoroAttributes>.activities.first?.id
        }
        #endif
        guard isRunning, let bg = backgroundDate else {
            pushLiveActivityUpdate(force: true)
            return
        }
        backgroundDate = nil
        fastForward(Date().timeIntervalSince(bg))
    }

    // MARK: - Timer Core

    private func play() {
        isRunning = true
        let remaining = pausedRemaining ?? timeRemaining
        stageEndDate = Date().addingTimeInterval(remaining)
        pausedRemaining = nil
        startTicker()
        startOrUpdateLiveActivity()
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        #endif
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
        pushLiveActivityUpdate(force: true)
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
    }

    private func startTicker() {
        timer?.cancel()
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard let end = stageEndDate else { return }

        if isCompressing, let startDate = compressionStartDate {
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
            pushLiveActivityUpdate()
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
        pushLiveActivityUpdate(force: true)
    }

    private func fastForward(_ elapsed: TimeInterval) {
        var remaining = elapsed
        var stage = currentStage
        var stageTime = timeRemaining

        while remaining >= stageTime {
            remaining -= stageTime
            stage = stage.next
            stageTime = stage.duration
        }

        currentStage = stage
        timeRemaining = stageTime - remaining
        stageEndDate = Date().addingTimeInterval(timeRemaining)
        pushLiveActivityUpdate(force: true)
    }

    // MARK: - Live Activity

    #if os(iOS)
    private func buildState() -> PomodoroAttributes.ContentState {
        let elapsed = currentStage.duration - timeRemaining
        let start = Date().addingTimeInterval(-elapsed)
        let allCases = PomodoroStage.allCases
        let idx = allCases.firstIndex(of: currentStage) ?? 0
        return .init(
            title: currentStage.islandLabel,
            totalSeconds: currentStage.duration,
            sessionCount: idx + 1,
            isPaused: !isRunning,
            currentTaskID: String(describing: currentStage),
            startTime: start
        )
    }

    private func findActivity() -> Activity<PomodoroAttributes>? {
        guard let id = liveActivityID else { return nil }
        return Activity<PomodoroAttributes>.activities.first { $0.id == id }
    }
    #endif

    private func startOrUpdateLiveActivity() {
        #if os(iOS)
        if let activity = findActivity() {
            let state = buildState()
            Task { await activity.update(.init(state: state, staleDate: nil)) }
            return
        }
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        print("🚀 areActivitiesEnabled: \(enabled)")
        guard enabled else {
            print("❌ Live Activities DISABLED in Settings")
            return
        }
        let attributes = PomodoroAttributes()
        let state = buildState()
        print("🚀 Requesting Island — title: \(state.title)")
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
            liveActivityID = activity.id
            print("🚀 Island ACTIVE — ID: \(activity.id)")
        } catch {
            print("❌ Island FAILED: \(error)")
        }
        #endif
    }

    private func pushLiveActivityUpdate(force: Bool = false) {
        #if os(iOS)
        guard let activity = findActivity() else { return }
        let now = Date()
        guard force || now.timeIntervalSince(lastLiveActivityUpdate) >= 0.5 else { return }
        lastLiveActivityUpdate = now
        let state = buildState()
        Task { await activity.update(.init(state: state, staleDate: nil)) }
        #endif
    }

    func endLiveActivity() {
        #if os(iOS)
        guard let activity = findActivity() else { return }
        let state = buildState()
        Task { await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate) }
        liveActivityID = nil
        #endif
    }

    // MARK: - Haptics

    private func hapticSoft() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    private func hapticHeavy() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }

    private func hapticMedium() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    private func hapticWarning() {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred(intensity: 0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            gen.impactOccurred(intensity: 0.4)
        }
        #endif
    }
}
