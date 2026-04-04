//
//  ContentView.swift
//  pomodoro
//
//  Created by msaxs_Lam on 4/4/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TimerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            viewModel.currentStage.backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: viewModel.currentStage)

            VStack(spacing: 12) {
                Text(viewModel.currentStage.label)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                Text(formatted(viewModel.timeRemaining))
                    .font(.system(size: 120, weight: .thin, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        }
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
        .onTapGesture {
            viewModel.togglePlayPause()
        }
        .onLongPressGesture(minimumDuration: 0.1, pressing: { isPressing in
            if isPressing {
                viewModel.startCompression()
            } else {
                viewModel.stopCompression()
            }
        }, perform: {})
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                viewModel.sceneDidEnterBackground()
            case .active:
                viewModel.sceneDidEnterForeground()
            default:
                break
            }
        }
    }

    private func formatted(_ time: TimeInterval) -> String {
        let total = Int(ceil(time))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
}
