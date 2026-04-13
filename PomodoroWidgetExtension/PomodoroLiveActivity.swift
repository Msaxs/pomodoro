import ActivityKit
import SwiftUI
import WidgetKit

private let amber = Color(red: 1.0, green: 0.75, blue: 0.0) // #FFBF00

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
        let expiryDate = s.startTime.addingTimeInterval(s.totalSeconds)
        let tint = stageColor(s.title)

        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .stroke(s.isPaused ? Color.gray : tint, lineWidth: 3.5)
                        .frame(width: 28, height: 28)
                    Circle()
                        .stroke(s.isPaused ? Color.gray.opacity(0.6) : nextStageColor(s.title), lineWidth: 2)
                        .frame(width: 14, height: 14)
                        .offset(x: 3, y: 3)
                }
                .frame(width: 34, height: 34)
            }
            DynamicIslandExpandedRegion(.trailing) {
                timerText(s, expiryDate: expiryDate, size: 18)
            }
            DynamicIslandExpandedRegion(.bottom) {
                thinProgressBar(s)
                    .padding(.leading, 60)
                    .padding(.trailing, 20)
                    .offset(y: -8)
            }
        } compactLeading: {
            ZStack(alignment: .center) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .stroke(s.isPaused ? Color.gray : tint, lineWidth: 2)
                        .frame(width: 14, height: 14)
                    Circle()
                        .stroke(s.isPaused ? Color.gray.opacity(0.6) : nextStageColor(s.title), lineWidth: 1.5)
                        .frame(width: 7, height: 7)
                        .offset(x: 2, y: 2)
                }
            }
            .frame(width: 26)
        } compactTrailing: {
            Text(formatted(s.remainingSeconds))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(s.isPaused ? tint.opacity(0.5) : tint)
                .lineLimit(1)
                .fixedSize()
        } minimal: {
            Text(formatted(s.remainingSeconds))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(s.isPaused ? tint.opacity(0.5) : tint)
                .lineLimit(1)
        }
    }

    // MARK: - Lock Screen

    @ViewBuilder
    private func lockScreenView(state s: PomodoroAttributes.ContentState) -> some View {
        let tint = stageColor(s.title)
        let expiryDate = s.startTime.addingTimeInterval(s.totalSeconds)

        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .stroke(s.isPaused ? Color.gray : tint, lineWidth: 5)
                    .frame(width: 42, height: 42)
                Circle()
                    .stroke(s.isPaused ? Color.gray.opacity(0.6) : nextStageColor(s.title), lineWidth: 3)
                    .frame(width: 21, height: 21)
                    .offset(x: 5, y: 5)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(stageName(s.title))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(s.isPaused ? tint.opacity(0.5) : tint)

                    Spacer()

                    timerText(s, expiryDate: expiryDate, size: 16)
                }

                thinProgressBar(s)
                    .frame(height: 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
    }

    // MARK: - Shared Helpers

    @ViewBuilder
    private func timerText(_ s: PomodoroAttributes.ContentState, expiryDate: Date, size: CGFloat) -> some View {
        let tint = stageColor(s.title)
        Group {
            if s.isPaused {
                Text(formatted(s.remainingSeconds))
            } else {
                Text(expiryDate, style: .timer)
                    .multilineTextAlignment(.trailing)
            }
        }
        .font(.system(size: size, weight: .bold, design: .monospaced))
        .monospacedDigit()
        .foregroundColor(s.isPaused ? tint.opacity(0.5) : tint)
        .lineLimit(1)
        .frame(width: size * 3.2, alignment: .trailing)
    }

    @ViewBuilder
    private func thinProgressBar(_ s: PomodoroAttributes.ContentState) -> some View {
        let tint = stageColor(s.title)
        let elapsed = Date().timeIntervalSince(s.stageStart)
        let progress = s.stageDuration > 0 ? min(max(elapsed / s.stageDuration, 0), 1) : 0

        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.2))
                    .frame(height: 4)
                Capsule()
                    .fill(s.isPaused ? tint.opacity(0.4) : tint)
                    .frame(width: geo.size.width * progress, height: 4)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Helpers

    private func stageColor(_ title: String) -> Color {
        switch stageName(title) {
        case "PREPARING":  return Color(red: 0.78, green: 0.92, blue: 1.0)
        case "DOMINATING": return amber
        case "RECOVERING": return Color(red: 0.6, green: 0.95, blue: 0.6)
        default:           return amber
        }
    }

    private func nextStageColor(_ title: String) -> Color {
        let parts = title.components(separatedBy: " ")
        let name = parts.first ?? ""
        let sessionNum = Int((parts.count > 1 ? parts[1] : "01/05").components(separatedBy: "/").first ?? "1") ?? 1

        switch name {
        case "PREPARING":  return amber
        case "DOMINATING": return sessionNum >= 5
                                ? Color(red: 0.2, green: 0.7, blue: 0.4)
                                : Color(red: 0.6, green: 0.95, blue: 0.6)
        default:           return Color(red: 0.78, green: 0.92, blue: 1.0)
        }
    }

    private func stageName(_ title: String) -> String {
        title.components(separatedBy: " ").first ?? title
    }

    private func formatted(_ time: Double) -> String {
        let t = Int(ceil(max(0, time)))
        let m = t / 60
        let s = t % 60
        if t > 600 {
            return String(format: "%02d:--", m)
        } else if t > 180 {
            return String(format: "%02d:%d-", m, s / 10)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}
