import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)       // #FFBF00
private let dimmedAmber = Color(red: 0.545, green: 0.396, blue: 0) // #8B6500
private let dimmedGray = Color.gray.opacity(0.5)

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroAttributes.self) { context in
            lockScreenView(state: context.state)
        } dynamicIsland: { context in
            islandView(state: context.state)
        }
    }

    // MARK: - Dynamic Island

    private func islandView(state s: PomodoroAttributes.ContentState) -> DynamicIsland {
        let tint = s.isPaused ? dimmedAmber : amber
        let dotColor = s.isPaused ? dimmedGray : amber
        let fade: Double = s.isPaused ? 0.5 : 1.0
        let remaining = computeRemaining(s)
        let expiryDate = s.startTime.addingTimeInterval(s.totalSeconds)

        return DynamicIsland {
            DynamicIslandExpandedRegion(.bottom) {
                VStack(spacing: 10) {
                    HStack {
                        Text(expandedName(s.title))
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(tint)
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 10) {
                            Text(formatted(remaining))
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(s.isPaused ? dimmedAmber : amber)
                                .lineLimit(1)
                                .fixedSize()

                            Button(intent: ToggleTimerIntent()) {
                                Image(systemName: s.isPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(amber)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Progress bar — no GeometryReader (unsupported in Live Activities)
                    ProgressView(value: progress(s))
                        .tint(tint)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .opacity(fade)
            }
        } compactLeading: {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .fixedSize()
                .opacity(fade)
        } compactTrailing: {
            liveTimer(s, expiryDate: expiryDate, remaining: remaining, size: 11)
                .frame(width: 44)
                .fixedSize()
                .opacity(fade)
        } minimal: {
            liveTimer(s, expiryDate: expiryDate, remaining: remaining, size: 10)
                .opacity(fade)
        }
    }

    // MARK: - Lock Screen Banner

    @ViewBuilder
    private func lockScreenView(state s: PomodoroAttributes.ContentState) -> some View {
        let tint = s.isPaused ? dimmedAmber : amber
        let fade: Double = s.isPaused ? 0.5 : 1.0
        let remaining = computeRemaining(s)
        let expiryDate = s.startTime.addingTimeInterval(s.totalSeconds)

        VStack(spacing: 10) {
            HStack {
                Text(expandedName(s.title))
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(tint)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 10) {
                    liveTimer(s, expiryDate: expiryDate, remaining: remaining, size: 18)
                        .fixedSize()

                    Button(intent: ToggleTimerIntent()) {
                        Image(systemName: s.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(amber)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }

            ProgressView(value: progress(s))
                .tint(tint)
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .opacity(fade)
        .background(Color.black)
    }

    // MARK: - Live Timer

    @ViewBuilder
    private func liveTimer(_ s: PomodoroAttributes.ContentState, expiryDate: Date, remaining: Double, size: CGFloat) -> some View {
        if s.isPaused {
            Text(formatted(remaining))
                .font(.system(size: size, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(dimmedAmber)
                .lineLimit(1)
        } else {
            Text(expiryDate, style: .timer)
                .font(.system(size: size, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(amber)
                .lineLimit(1)
        }
    }

    // MARK: - Helpers

    private func expandedName(_ title: String) -> String {
        title.components(separatedBy: " ").first ?? title
    }

    private func computeRemaining(_ s: PomodoroAttributes.ContentState) -> Double {
        let elapsed = Date().timeIntervalSince(s.startTime)
        return max(0, s.totalSeconds - elapsed)
    }

    private func progress(_ s: PomodoroAttributes.ContentState) -> Double {
        let elapsed = Date().timeIntervalSince(s.startTime)
        return max(0, min(1, elapsed / s.totalSeconds))
    }

    private func formatted(_ time: Double) -> String {
        let t = Int(ceil(max(0, time)))
        return String(format: "%02d:%02d", t / 60, t % 60)
    }
}
