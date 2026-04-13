//
//  ContentView.swift
//  pomodoro
//
//  Created by msaxs_Lam on 4/4/2026.
//

import SwiftUI

private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)

struct ContentView: View {
    @ObservedObject var viewModel: TimerViewModel
    @State private var isPressing = false
    @State private var isAccelerating = false

    var body: some View {
        ZStack {
            viewModel.currentStage.backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: viewModel.currentStage)

            Color.black
                .ignoresSafeArea()
                .opacity(isAccelerating ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.8), value: isAccelerating)

            VStack(spacing: 4) {
                Text(viewModel.currentStage.label)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .blur(radius: blurRadius(for: viewModel.compressionMultiplier, max: 3))

                Text(formatted(viewModel.timeRemaining))
                    .font(.system(size: 150, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.1)
                    .contentTransition(.numericText())
                    .blur(radius: blurRadius(for: viewModel.compressionMultiplier, max: 5))
                    .shadow(color: viewModel.isCompressing ? viewModel.currentStage.accentColor : .clear,
                            radius: viewModel.isCompressing ? 10 : 0)
            }
            .animation(.easeInOut(duration: 0.5), value: viewModel.currentStage)
            .opacity(isPressing ? 0.4 : (viewModel.isRunning ? 1.0 : 0.6))
            .scaleEffect(isPressing ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressing)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isCompressing)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        isAccelerating = true
                        viewModel.startCompression()
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressing = true }
                    .onEnded { _ in
                        isPressing = false
                        if !isAccelerating {
                            viewModel.togglePlayPause()
                        }
                        isAccelerating = false
                        viewModel.stopCompression()
                    }
            )
        }
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
    }

    /// Blur kicks in above 20x, reaches cap at 120x.
    private func blurRadius(for multiplier: Double, max maxRadius: Double) -> Double {
        guard multiplier > 20 else { return 0 }
        return min((multiplier - 20) / 100.0 * maxRadius, maxRadius)
    }

    private func formatted(_ time: TimeInterval) -> String {
        let total = Int(ceil(time))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView(viewModel: TimerViewModel())
}
