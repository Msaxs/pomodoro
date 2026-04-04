//
//  pomodoroApp.swift
//  pomodoro
//
//  Created by msaxs_Lam on 4/4/2026.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .landscape
    }

    // Called by iOS before the process is terminated — end all activities immediately
    func applicationWillTerminate(_ application: UIApplication) {
        ActivityManager.shared.endAllActivities()
    }
}
#endif

@main
struct pomodoroApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @StateObject private var viewModel = TimerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                #if os(iOS)
                // Belt-and-suspenders: notification fires for system-initiated termination
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.willTerminateNotification
                    )
                ) { _ in
                    ActivityManager.shared.endAllActivities()
                }
                #endif
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                viewModel.sceneDidEnterBackground()
                if !viewModel.isRunning {
                    // Timer is idle — no reason for the Island to persist in background
                    ActivityManager.shared.endAllActivities()
                }
            case .active:
                viewModel.sceneDidEnterForeground()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
