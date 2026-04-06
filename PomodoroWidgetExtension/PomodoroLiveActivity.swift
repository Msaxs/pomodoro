import ActivityKit
import SwiftUI
import WidgetKit

private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)
private let dimmedAmber = Color(red: 0.545, green: 0.396, blue: 0)

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroAttributes.self) { context in
            lockScreenView(state: context.state)
        } dynamicIsland: { context in
            islandView(state: context.state)
        }
    }

    private func islandView(state s: PomodoroAttributes.ContentState) -> DynamicIsland {
        let tint = s.isPaused ? dimmedAmber : amber
        let fade: Double = s.isPaused ? 0.5 : 1.0

        return DynamicIsland {
            DynamicIslandExpandedRegion(.bottom) {
                HStack {
                    Text(expandedName(s.title))
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(tint)
                        .lineLimit(1)

                    Spacer()

                    Text(formatted(remaining(s)))
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .fixedSize()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .opacity(fade)
            }
        } compactLeading: {
            Circle()
                .fill(s.isPaused ? Color.gray.opacity(0.5) : amber)
                .frame(width: 6, height: 6)
                .fixedSize()
                .opacity(fade)
        } compactTrailing: {
            Text(formatted(remaining(s)))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(tint)
                .frame(width: 44)
                .fixedSize()
                .opacity(fade)
        } minimal: {
            Text(formatted(remaining(s)))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(tint)
                .opacity(fade)
        }
    }

    @ViewBuilder
    private func lockScreenView(state s: PomodoroAttributes.ContentState) -> some View {
        let tint = s.isPaused ? dimmedAmber : amber
        let fade: Double = s.isPaused ? 0.5 : 1.0

        HStack {
            Text(expandedName(s.title))
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(tint)
                .lineLimit(1)

            Spacer()

            Text(formatted(remaining(s)))
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .opacity(fade)
        .background(Color.black)
    }

    // MARK: - Helpers

    private func expandedName(_ title: String) -> String {
        title.components(separatedBy: " ").first ?? title
    }

    private func remaining(_ s: PomodoroAttributes.ContentState) -> Double {
        let elapsed = Date().timeIntervalSince(s.startTime)
        return max(0, s.totalSeconds - elapsed)
    }

    private func formatted(_ time: Double) -> String {
        let t = Int(ceil(max(0, time)))
        return String(format: "%02d:%02d", t / 60, t % 60)
    }
}
