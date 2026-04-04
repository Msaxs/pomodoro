import ActivityKit
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

        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                Text(s.stageName)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.leading, 8)
                    .opacity(fade)
            }
            DynamicIslandExpandedRegion(.trailing) {
                timerView(s, size: 18)
                    .multilineTextAlignment(.trailing)
                    .padding(.trailing, 8)
                    .opacity(fade)
            }
            DynamicIslandExpandedRegion(.bottom) {
                ProgressView(
                    value: max(0, min(1, 1 - s.timeRemaining / s.totalDuration))
                )
                .tint(tint)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
                .opacity(fade)
            }
        } compactLeading: {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .fixedSize()
                .opacity(fade)
        } compactTrailing: {
            timerView(s, size: 11)
                .frame(width: 44)
                .fixedSize()
                .opacity(fade)
        } minimal: {
            timerView(s, size: 10)
                .opacity(fade)
        }
    }

    // MARK: - Timer — live when running, static when paused

    @ViewBuilder
    private func timerView(_ s: PomodoroAttributes.ContentState, size: CGFloat) -> some View {
        if s.isPaused {
            Text(formatted(s.timeRemaining))
                .font(.system(size: size, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(s.isPaused ? dimmedAmber : amber)
        } else {
            Text(s.expiryDate, style: .timer)
                .font(.system(size: size, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(amber)
        }
    }

    // MARK: - Lock Screen Banner

    @ViewBuilder
    private func lockScreenView(state s: PomodoroAttributes.ContentState) -> some View {
        let tint = s.isPaused ? dimmedAmber : amber
        let dotColor = s.isPaused ? dimmedGray : amber
        let fade: Double = s.isPaused ? 0.5 : 1.0

        HStack(spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .padding(.leading, 16)

            Text(s.stageName)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(tint)
                .lineLimit(1)

            Spacer()

            ProgressView(
                value: max(0, min(1, 1 - s.timeRemaining / s.totalDuration))
            )
            .tint(tint)
            .frame(width: 56)

            timerView(s, size: 16)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 14)
        .opacity(fade)
        .background(Color.black)
    }

    // MARK: - Helpers

    private func formatted(_ time: Double) -> String {
        let t = Int(ceil(max(0, time)))
        return String(format: "%02d:%02d", t / 60, t % 60)
    }
}
