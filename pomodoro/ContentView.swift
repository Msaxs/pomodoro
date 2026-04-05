//
//  ContentView.swift
//  pomodoro
//
//  Created by msaxs_Lam on 4/4/2026.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: TimerViewModel

    var body: some View {
        ZStack {
            viewModel.currentStage.backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: viewModel.currentStage)

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
            }
        }
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
        .onTapGesture {
            viewModel.togglePlayPause()
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { isPressing in
            if isPressing {
                viewModel.startCompression()
            } else {
                viewModel.stopCompression()
            }
        }, perform: {})
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
