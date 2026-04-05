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

    // Called by iOS before the process is terminated — block until Island is gone
    func applicationWillTerminate(_ application: UIApplication) {
        ActivityManager.shared.terminateAllNow()
    }
}
#endif

@main
struct pomodoroApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @MainActor private var viewModel: TimerViewModel { TimerViewModel.shared }
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
                    ActivityManager.shared.terminateAllNow()
                }
                #endif
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                viewModel.sceneDidEnterBackground()
                // Island stays alive — it will persist in background
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
